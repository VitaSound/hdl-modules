#pragma once

#include <cstdint>
#include <string>

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
using socket_t = SOCKET;
#else
using socket_t = int;
#endif

struct UdpEndpoint {
    std::string host;
    uint16_t port = 0;
};

bool parseHostPort(const std::string& s, UdpEndpoint& out);

class UdpSocket {
public:
    UdpSocket() = default;
    ~UdpSocket();

    UdpSocket(const UdpSocket&) = delete;
    UdpSocket& operator=(const UdpSocket&) = delete;

    bool bind(const std::string& host, uint16_t port);
    bool open();
    void close();

    bool setReuseAddress(bool enable);
    bool setRecvTimeoutMs(int timeout_ms);
    bool setSendBufferBytes(int bytes);
    bool setRecvBufferBytes(int bytes);

    ssize_t sendTo(const uint8_t* data, size_t len, const UdpEndpoint& dest);
    ssize_t recvFrom(uint8_t* data, size_t max_len, UdpEndpoint& src);

    int fd() const { return fd_; }

private:
    int fd_ = -1;
};
