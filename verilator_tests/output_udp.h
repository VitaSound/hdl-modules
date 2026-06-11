#pragma once

#include <cstdint>
#include <string>

#include "shared_state.h"
#include "synth_core.h"
#include "udp_session.h"

struct UdpOutputConfig {
    uint16_t blockFrames = 256;
    uint8_t channels = 2;
};

int runUdpOutput(SynthCore& synth,
                 SharedState& state,
                 UdpSessionState& session,
                 const UdpOutputConfig& cfg);
