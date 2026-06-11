#include "net_socket.h"

#include <arpa/inet.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>
#include <sys/time.h>

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
    fd_ = ::socket(AF_INET, SOCK_DGRAM, 0);
    if (fd_ < 0) {
        std::cerr << "socket() failed: " << std::strerror(errno) << "\n";
        return false;
    }
    return true;
}

void UdpSocket::close() {
    if (fd_ >= 0) {
        ::close(fd_);
        fd_ = -1;
    }
}

bool UdpSocket::setReuseAddress(bool enable) {
    if (fd_ < 0) {
        return false;
    }
    const int opt = enable ? 1 : 0;
    return ::setsockopt(fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) == 0;
}

bool UdpSocket::setRecvTimeoutMs(int timeout_ms) {
    if (fd_ < 0) {
        return false;
    }
    timeval tv{};
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;
    return ::setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) == 0;
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

    if (::bind(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        std::cerr << "bind() failed on " << host << ":" << port << ": "
                  << std::strerror(errno) << "\n";
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
        std::cerr << "getaddrinfo(" << ep.host << ") failed: " << gai_strerror(rc) << "\n";
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
        const ssize_t sent =
            ::sendto(fd_, data, len, 0, reinterpret_cast<sockaddr*>(&addr), sizeof(addr));
        if (sent >= 0) {
            return sent;
        }
        if (errno == EINTR) {
            continue;
        }
        std::cerr << "sendto() failed: " << std::strerror(errno) << "\n";
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
        const ssize_t n = ::recvfrom(
            fd_, data, max_len, 0, reinterpret_cast<sockaddr*>(&addr), &addr_len);
        if (n >= 0) {
            char host_buf[INET_ADDRSTRLEN]{};
            ::inet_ntop(AF_INET, &addr.sin_addr, host_buf, sizeof(host_buf));
            src.host = host_buf;
            src.port = ntohs(addr.sin_port);
            return n;
        }
        if (errno == EINTR) {
            continue;
        }
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == ETIMEDOUT) {
            return 0;
        }
        std::cerr << "recvfrom() failed: " << std::strerror(errno) << "\n";
        return -1;
    }
}
