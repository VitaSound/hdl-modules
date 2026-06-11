#pragma once

#include <cstdint>
#include <string>

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

    ssize_t sendTo(const uint8_t* data, size_t len, const UdpEndpoint& dest);
    ssize_t recvFrom(uint8_t* data, size_t max_len, UdpEndpoint& src);

    int fd() const { return fd_; }

private:
    int fd_ = -1;
};
