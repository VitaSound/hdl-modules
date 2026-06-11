#include "main_udp.h"

#include "input_udp.h"
#include "output_udp.h"
#include "shared_state.h"
#include "synth_core.h"
#include "net_socket.h"

#include "verilated.h"

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdint>
#include <iostream>
#include <string>
#include <thread>

namespace {
std::atomic<bool>* g_running_ptr = nullptr;

constexpr uint32_t DEFAULT_SAMPLE_RATE = 48000;

void onSignal(int) {
    if (g_running_ptr != nullptr) {
        g_running_ptr->store(false, std::memory_order_relaxed);
    }
}

void printUsage() {
    std::cerr
        << "Vgenerator UDP engine (MIDI in / PCM out for VST bridge)\n"
        << "Options:\n"
        << "  --udp-bind HOST:PORT (default 0.0.0.0:5004)\n"
        << "  --sample-rate R (default 48000)\n"
        << "  --udp-block-frames N (default 256)\n"
        << "  --help\n";
}
} // namespace

int runUdpEngineMain(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    SharedState state;
    g_running_ptr = &state.running;
    std::signal(SIGINT, onSignal);
#ifndef _WIN32
    std::signal(SIGTERM, onSignal);
#endif

    uint32_t sampleRate = DEFAULT_SAMPLE_RATE;
    std::string udpBind = "0.0.0.0:5004";
    uint16_t udpBlockFrames = 256;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--udp-bind" && i + 1 < argc) {
            udpBind = argv[++i];
        } else if (arg == "--sample-rate" && i + 1 < argc) {
            sampleRate = static_cast<uint32_t>(std::stoul(argv[++i]));
        } else if (arg == "--udp-block-frames" && i + 1 < argc) {
            udpBlockFrames = static_cast<uint16_t>(std::stoul(argv[++i]));
        } else if (arg == "--help" || arg == "-h") {
            printUsage();
            return 0;
        } else {
            std::cerr << "Unknown option: " << arg << "\n";
            printUsage();
            return 1;
        }
    }

    SynthCore synth;
    if (!synthInit(synth, sampleRate, 2)) {
        return 1;
    }

    UdpSessionState udpSession;
    UdpInputConfig cfg;
    UdpEndpoint bindEp;
    if (!parseHostPort(udpBind, bindEp)) {
        std::cerr << "Invalid --udp-bind: " << udpBind << "\n";
        synthDestroy(synth);
        return 1;
    }
    cfg.bindHost = bindEp.host;
    cfg.controlPort = bindEp.port;

    std::thread inputThread = startUdpInput(cfg, state, udpSession);

    UdpOutputConfig udpOutCfg;
    udpOutCfg.blockFrames = udpBlockFrames;
    udpOutCfg.channels = 2;

    int outputResult = 0;
    std::thread outputThread([&]() {
        outputResult = runUdpOutput(synth, state, udpSession, udpOutCfg);
        state.running.store(false, std::memory_order_relaxed);
    });

    std::cerr << "UDP engine | control " << cfg.bindHost << ":" << cfg.controlPort
              << " | Ctrl+C to quit\n";

    while (state.running.load(std::memory_order_relaxed)) {
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    if (outputThread.joinable()) {
        outputThread.join();
    }
    if (inputThread.joinable()) {
        inputThread.join();
    }

    synthDestroy(synth);
    return outputResult;
}

#ifdef HDL_ENGINE_UDP_MAIN
int main(int argc, char** argv) {
    return runUdpEngineMain(argc, argv);
}
#endif
