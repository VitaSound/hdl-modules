#include "output_udp.h"

#include <chrono>
#include <iostream>
#include <thread>

int runUdpOutput(SynthCore& /*synth*/,
                 SharedState& state,
                 UdpSessionState& /*session*/,
                 const UdpOutputConfig& /*cfg*/) {
    std::cerr << "UDP output: pull-only mode — PCM is sent on AudioPull in input_udp\n";
    while (state.running.load(std::memory_order_relaxed)) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    return 0;
}
