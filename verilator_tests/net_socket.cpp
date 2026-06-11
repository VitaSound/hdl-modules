#include "net_socket.h"

#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
#include <ws2tcpip.h>

#pragma comment(lib, "ws2_32")

namespace {
struct WsaInit {
    WsaInit() {
        WSADATA wsa{};
        if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
            std::cerr << "WSAStartup failed\n";
        }
    }
    ~WsaInit() { WSACleanup(); }
};

const WsaInit g_wsa_init{};

int lastSocketError() {
    return WSAGetLastError();
}

bool isWouldBlock(int err) {
    return err == WSAEWOULDBLOCK || err == WSAETIMEDOUT;
}

bool isInterrupted(int err) {
    return err == WSAEINTR;
}
} // namespace
#else
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

namespace {
int lastSocketError() {
    return errno;
}

bool isWouldBlock(int err) {
    return err == EAGAIN || err == EWOULDBLOCK || err == ETIMEDOUT;
}

bool isInterrupted(int err) {
    return err == EINTR;
}
} // namespace
#endif

bool parseHostPort(const std::string& s, UdpEndpoint& out) {
    const size_t pos = s.rfind(':');
    if (pos == std::string::npos || pos == 0 || pos + 1 >= s.size()) {
        return false;
    }
    try {
        const int port = std::stoi(s.substr(pos + 1));
        if (port < 0 || port > 65535) {
            return false;
        }
        out.host = s.substr(0, pos);
        out.port = static_cast<uint16_t>(port);
    } catch (...) {
        return false;
    }
    return true;
}

UdpSocket::~UdpSocket() {
    close();
}

bool UdpSocket::open() {
    if (fd_ >= 0) {
        return true;
    }
#ifdef _WIN32
    fd_ = static_cast<int>(::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP));
#else
    fd_ = ::socket(AF_INET, SOCK_DGRAM, 0);
#endif
    if (fd_ < 0) {
        std::cerr << "socket() failed: " << lastSocketError() << "\n";
        return false;
    }
    return true;
}

void UdpSocket::close() {
    if (fd_ >= 0) {
#ifdef _WIN32
        ::closesocket(static_cast<SOCKET>(fd_));
#else
        ::close(fd_);
#endif
        fd_ = -1;
    }
}

bool UdpSocket::setReuseAddress(bool enable) {
    if (fd_ < 0) {
        return false;
    }
    const int opt = enable ? 1 : 0;
    return ::setsockopt(static_cast<socket_t>(fd_),
                        SOL_SOCKET,
                        SO_REUSEADDR,
                        reinterpret_cast<const char*>(&opt),
                        sizeof(opt)) == 0;
}

bool UdpSocket::setRecvTimeoutMs(int timeout_ms) {
    if (fd_ < 0) {
        return false;
    }
#ifdef _WIN32
    DWORD tv = static_cast<DWORD>(timeout_ms);
    return ::setsockopt(static_cast<socket_t>(fd_),
                        SOL_SOCKET,
                        SO_RCVTIMEO,
                        reinterpret_cast<const char*>(&tv),
                        sizeof(tv)) == 0;
#else
    timeval tv{};
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;
    return ::setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) == 0;
#endif
}

bool UdpSocket::setSendBufferBytes(int bytes) {
    if (fd_ < 0) {
        return false;
    }
    return ::setsockopt(static_cast<socket_t>(fd_),
                        SOL_SOCKET,
                        SO_SNDBUF,
                        reinterpret_cast<const char*>(&bytes),
                        sizeof(bytes)) == 0;
}

bool UdpSocket::setRecvBufferBytes(int bytes) {
    if (fd_ < 0) {
        return false;
    }
    return ::setsockopt(static_cast<socket_t>(fd_),
                        SOL_SOCKET,
                        SO_RCVBUF,
                        reinterpret_cast<const char*>(&bytes),
                        sizeof(bytes)) == 0;
}

bool UdpSocket::bind(const std::string& host, uint16_t port) {
    if (!open()) {
        return false;
    }

    setReuseAddress(true);

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);

    if (host.empty() || host == "0.0.0.0") {
        addr.sin_addr.s_addr = INADDR_ANY;
    } else if (::inet_pton(AF_INET, host.c_str(), &addr.sin_addr) != 1) {
        std::cerr << "Invalid bind address: " << host << "\n";
        return false;
    }

    if (::bind(static_cast<socket_t>(fd_),
               reinterpret_cast<sockaddr*>(&addr),
               sizeof(addr)) != 0) {
        std::cerr << "bind() failed on " << host << ":" << port << ": " << lastSocketError()
                  << "\n";
        return false;
    }
    return true;
}

static bool resolveEndpoint(const UdpEndpoint& ep, sockaddr_in& addr) {
    std::memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(ep.port);

    if (::inet_pton(AF_INET, ep.host.c_str(), &addr.sin_addr) == 1) {
        return true;
    }

    addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    addrinfo* res = nullptr;
    const int rc = ::getaddrinfo(ep.host.c_str(), nullptr, &hints, &res);
    if (rc != 0 || res == nullptr) {
#ifdef _WIN32
        std::cerr << "getaddrinfo(" << ep.host << ") failed: " << rc << "\n";
#else
        std::cerr << "getaddrinfo(" << ep.host << ") failed: " << gai_strerror(rc) << "\n";
#endif
        return false;
    }
    const auto* in = reinterpret_cast<sockaddr_in*>(res->ai_addr);
    addr.sin_addr = in->sin_addr;
    ::freeaddrinfo(res);
    return true;
}

ssize_t UdpSocket::sendTo(const uint8_t* data, size_t len, const UdpEndpoint& dest) {
    if (fd_ < 0) {
        return -1;
    }
    sockaddr_in addr{};
    if (!resolveEndpoint(dest, addr)) {
        return -1;
    }
    while (true) {
        const int sent = ::sendto(static_cast<socket_t>(fd_),
                                  reinterpret_cast<const char*>(data),
                                  static_cast<int>(len),
                                  0,
                                  reinterpret_cast<sockaddr*>(&addr),
                                  sizeof(addr));
        if (sent >= 0) {
            return sent;
        }
        const int err = lastSocketError();
        if (isInterrupted(err)) {
            continue;
        }
        std::cerr << "sendto() failed: " << err << "\n";
        return -1;
    }
}

ssize_t UdpSocket::recvFrom(uint8_t* data, size_t max_len, UdpEndpoint& src) {
    if (fd_ < 0) {
        return -1;
    }
    sockaddr_in addr{};
    socklen_t addr_len = sizeof(addr);
    while (true) {
        const int n = ::recvfrom(static_cast<socket_t>(fd_),
                                 reinterpret_cast<char*>(data),
                                 static_cast<int>(max_len),
                                 0,
                                 reinterpret_cast<sockaddr*>(&addr),
                                 &addr_len);
        if (n >= 0) {
            char host_buf[INET_ADDRSTRLEN]{};
            ::inet_ntop(AF_INET, &addr.sin_addr, host_buf, sizeof(host_buf));
            src.host = host_buf;
            src.port = ntohs(addr.sin_port);
            return n;
        }
        const int err = lastSocketError();
        if (isInterrupted(err)) {
            continue;
        }
        if (isWouldBlock(err)) {
            return 0;
        }
        std::cerr << "recvfrom() failed: " << err << "\n";
        return -1;
    }
}
