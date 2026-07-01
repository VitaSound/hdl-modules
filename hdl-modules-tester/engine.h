#pragma once

#include <cstdint>
#include <string>
#include <thread>

#include "protocol/hdl_net.h"
#include "shared_state.h"
#include "udp_session.h"

struct SynthCore;

struct EngineConfig {
    std::string bindHost = "0.0.0.0";
    uint16_t controlPort = hdlnet::kDefaultControlPort;
    uint32_t engineSsrc = 0x454E474Eu; // "ENGN"
    uint16_t packetFrames = hdlnet::kMaxAudioFrames;
    uint8_t audioChannels = 2;
    uint16_t maxFramesPerPull = hdlnet::kDefaultMaxFramesPerPull;
    uint16_t caps = 0;
};

std::thread startEngine(const EngineConfig& cfg,
                        SharedState& state,
                        UdpSessionState& session,
                        SynthCore& synth);
