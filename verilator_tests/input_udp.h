#pragma once

#include <cstdint>
#include <string>
#include <thread>

#include "shared_state.h"
#include "udp_session.h"

struct UdpInputConfig {
    std::string bindHost = "0.0.0.0";
    uint16_t controlPort = hdlnet::kDefaultControlPort;
    uint32_t engineSsrc = 0x454E474Eu; // "ENGN"
};

std::thread startUdpInput(const UdpInputConfig& cfg, SharedState& state, UdpSessionState& session);
