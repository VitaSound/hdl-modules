#pragma once

#include <cstdint>
#include <string>
#include <thread>

#include "protocol/hdl_net.h"
#include "shared_state.h"
#include "synth_core.h"
#include "udp_session.h"

struct UdpInputConfig {
    std::string bindHost = "0.0.0.0";
    uint16_t controlPort = hdlnet::kDefaultControlPort;
    uint32_t engineSsrc = 0x454E474Eu; // "ENGN"
    uint16_t packetFrames = hdlnet::kMaxAudioFrames;
    uint8_t audioChannels = 2;
    uint16_t maxFramesPerPull = hdlnet::kDefaultMaxFramesPerPull;
};

std::thread startUdpInput(const UdpInputConfig& cfg,
                          SharedState& state,
                          UdpSessionState& session,
                          SynthCore& synth);
