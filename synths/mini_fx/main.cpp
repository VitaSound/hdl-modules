#include "engine.h"
#include "net_socket.h"
#include "shared_state.h"
#include "synth_core.h"

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

constexpr uint32_t DEFAULT_SAMPLE_RATE = 44100;
constexpr const char* DEFAULT_PARAMS_YAML = "synths/mini_fx/mini_fx.params.yaml";

void onSignal(int) {
    if (g_running_ptr != nullptr) {
        g_running_ptr->store(false, std::memory_order_relaxed);
    }
}

void printUsage() {
    std::cerr
        << "MiniFX UDP engine (insert SVF filter, AudioPush + AudioPull)\n"
        << "Options:\n"
        << "  --udp-bind HOST:PORT (default 0.0.0.0:5004)\n"
        << "  --sample-rate R (default 44100)\n"
        << "  --udp-block-frames N (default 256)\n"
        << "  --params-yaml PATH (default synths/mini_fx/mini_fx.params.yaml)\n"
        << "  --midi-log           print MIDI bytes/events to stderr\n"
        << "  --help\n";
}
} // namespace

int main(int argc, char** argv) {
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
    std::string paramsYamlPath = DEFAULT_PARAMS_YAML;
    bool midiLog = false;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--udp-bind" && i + 1 < argc) {
            udpBind = argv[++i];
        } else if (arg == "--sample-rate" && i + 1 < argc) {
            sampleRate = static_cast<uint32_t>(std::stoul(argv[++i]));
        } else if (arg == "--udp-block-frames" && i + 1 < argc) {
            udpBlockFrames = static_cast<uint16_t>(std::stoul(argv[++i]));
        } else if (arg == "--params-yaml" && i + 1 < argc) {
            paramsYamlPath = argv[++i];
        } else if (arg == "--midi-log") {
            midiLog = true;
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
    if (!synthInit(synth, sampleRate)) {
        return 1;
    }
    synth.midiLog = midiLog;

    UdpSessionState session;
    EngineConfig cfg;
    UdpEndpoint bindEp;
    if (!parseHostPort(udpBind, bindEp)) {
        std::cerr << "Invalid --udp-bind: " << udpBind << "\n";
        synthDestroy(synth);
        return 1;
    }
    cfg.bindHost = bindEp.host;
    cfg.controlPort = bindEp.port;
    cfg.packetFrames = udpBlockFrames;
    cfg.caps = hdlnet::kCapAudioPush;
    cfg.paramsYamlPath = paramsYamlPath;

    std::thread engineThread = startEngine(cfg, state, session, synth);

    std::cerr << "MiniFX | control " << cfg.bindHost << ":" << cfg.controlPort
              << " | AudioPush + pull";
    if (midiLog) {
        std::cerr << " | midi-log";
    }
    std::cerr << " | Ctrl+C to quit\n";

    while (state.running.load(std::memory_order_relaxed)) {
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    if (engineThread.joinable()) {
        engineThread.join();
    }

    synthDestroy(synth);
    return 0;
}
