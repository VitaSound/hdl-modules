#include "verilated.h"

#include "input_keyboard.h"
#include "input_midi.h"
#include "input_udp.h"
#include "output_soundcard.h"
#include "output_udp.h"
#include "output_wav.h"
#include "shared_state.h"
#include "synth_core.h"
#include "terminal_input.h"
#include "net_socket.h"

#include <atomic>
#include <csignal>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <string>
#include <thread>

namespace {
std::atomic<bool>* g_running_ptr = nullptr;

constexpr uint32_t DEFAULT_SAMPLE_RATE = 48000;
constexpr uint32_t DEFAULT_WAV_SECONDS = 10;

enum class InputSource {
    Keyboard,
    Midi,
    Udp
};

enum class OutputMode {
    Soundcard,
    Wav,
    Udp
};

void onSignal(int) {
    if (g_running_ptr != nullptr) {
        g_running_ptr->store(false, std::memory_order_relaxed);
    }
}

void printUsage() {
    std::cerr
        << "Options:\n"
        << "  --input-source keyboard|midi|udp\n"
        << "  --input-device /dev/input/eventX\n"
        << "  --list-midi\n"
        << "  --midi-port C:P\n"
        << "  --udp-bind HOST:PORT (default 0.0.0.0:5004)\n"
        << "  --output-mode soundcard|wav|udp\n"
        << "  --list-devices\n"
        << "  --device-index N\n"
        << "  --sample-rate R\n"
        << "  --udp-block-frames N (default 256)\n"
        << "  --wav-path FILE\n"
        << "  --wav-seconds N\n";
}
} // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    SharedState state;
    g_running_ptr = &state.running;
    std::signal(SIGINT, onSignal);
    std::signal(SIGTERM, onSignal);

    InputSource inputSource = InputSource::Keyboard;
    OutputMode outputMode = OutputMode::Soundcard;

    std::string inputDevice = "/dev/input/event2";
    std::string midiPortArg;
    bool listMidiOnly = false;

    bool listDevicesOnly = false;
    int requestedOutputDevice = -1;
    uint32_t sampleRate = DEFAULT_SAMPLE_RATE;

    std::string wavPath = "output.wav";
    uint32_t wavSeconds = DEFAULT_WAV_SECONDS;

    std::string udpBind = "0.0.0.0:5004";
    uint16_t udpBlockFrames = 256;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--input-source" && i + 1 < argc) {
            const std::string src = argv[++i];
            if (src == "keyboard") {
                inputSource = InputSource::Keyboard;
            } else if (src == "midi") {
                inputSource = InputSource::Midi;
            } else if (src == "udp") {
                inputSource = InputSource::Udp;
            } else {
                std::cerr << "Unknown --input-source: " << src << "\n";
                printUsage();
                return 1;
            }
        } else if (arg == "--input-device" && i + 1 < argc) {
            inputDevice = argv[++i];
        } else if (arg == "--list-midi") {
            listMidiOnly = true;
        } else if (arg == "--midi-port" && i + 1 < argc) {
            midiPortArg = argv[++i];
        } else if (arg == "--udp-bind" && i + 1 < argc) {
            udpBind = argv[++i];
        } else if (arg == "--udp-block-frames" && i + 1 < argc) {
            udpBlockFrames = static_cast<uint16_t>(std::stoul(argv[++i]));
        } else if (arg == "--output-mode" && i + 1 < argc) {
            const std::string mode = argv[++i];
            if (mode == "soundcard") {
                outputMode = OutputMode::Soundcard;
            } else if (mode == "wav") {
                outputMode = OutputMode::Wav;
            } else if (mode == "udp") {
                outputMode = OutputMode::Udp;
            } else {
                std::cerr << "Unknown --output-mode: " << mode << "\n";
                printUsage();
                return 1;
            }
        } else if (arg == "--list-devices") {
            listDevicesOnly = true;
        } else if (arg == "--device-index" && i + 1 < argc) {
            requestedOutputDevice = std::stoi(argv[++i]);
        } else if (arg == "--sample-rate" && i + 1 < argc) {
            sampleRate = static_cast<uint32_t>(std::stoul(argv[++i]));
        } else if (arg == "--wav-path" && i + 1 < argc) {
            wavPath = argv[++i];
        } else if (arg == "--wav-seconds" && i + 1 < argc) {
            wavSeconds = static_cast<uint32_t>(std::stoul(argv[++i]));
        } else if (arg == "--help" || arg == "-h") {
            printUsage();
            return 0;
        } else {
            std::cerr << "Unknown option: " << arg << "\n";
            printUsage();
            return 1;
        }
    }

    int midiClient = -1;
    int midiPort = -1;
    if (inputSource == InputSource::Midi || listMidiOnly) {
        const auto ports = listMidiInputPorts();
        std::cerr << "ALSA MIDI input ports:\n";
        for (const auto& p : ports) {
            std::cerr << "  " << p.client << ":" << p.port
                      << " | " << p.clientName
                      << " | " << p.portName << "\n";
        }

        if (listMidiOnly) {
            return 0;
        }

        if (ports.empty()) {
            std::cerr << "No MIDI input ports available.\n";
            return 1;
        }

        if (midiPortArg.empty()) {
            std::cerr << "Enter MIDI port as client:port: ";
            std::cerr.flush();
            if (!(std::cin >> midiPortArg)) {
                std::cerr << "Invalid MIDI port input.\n";
                return 1;
            }
        }

        if (!parseMidiPort(midiPortArg, midiClient, midiPort)) {
            std::cerr << "Invalid MIDI port format: " << midiPortArg << "\n";
            return 1;
        }
    }

    if (outputMode == OutputMode::Soundcard || listDevicesOnly) {
        const PaError paInit = Pa_Initialize();
        if (paInit != paNoError) {
            std::cerr << "PortAudio init error: " << Pa_GetErrorText(paInit) << "\n";
            return 1;
        }

        const auto devices = listOutputDevices();
        std::cerr << "PortAudio output devices:\n";
        for (const auto& d : devices) {
            std::cerr << "  [" << d.index << "] " << d.name
                      << " | api=" << d.api
                      << " | out_ch=" << d.maxChannels
                      << " | default_sr=" << d.defaultSampleRate << "\n";
        }

        if (listDevicesOnly) {
            Pa_Terminate();
            return 0;
        }

        if (devices.empty()) {
            std::cerr << "No output devices found.\n";
            Pa_Terminate();
            return 1;
        }

        if (requestedOutputDevice < 0) {
            std::cerr << "Enter output device index: ";
            std::cerr.flush();
            if (!(std::cin >> requestedOutputDevice)) {
                std::cerr << "Invalid output device input.\n";
                Pa_Terminate();
                return 1;
            }
        }
    }

    SynthCore synth;
    const int synthChannels =
        (outputMode == OutputMode::Udp || outputMode == OutputMode::Soundcard) ? 2 : 1;
    if (!synthInit(synth, sampleRate, synthChannels)) {
        if (outputMode == OutputMode::Soundcard || listDevicesOnly) {
            Pa_Terminate();
        }
        return 1;
    }

    UdpSessionState udpSession;
    std::thread inputThread;
    if (inputSource == InputSource::Midi) {
        inputThread = startMidiInput(midiClient, midiPort, state);
    } else if (inputSource == InputSource::Udp) {
        UdpInputConfig cfg;
        UdpEndpoint bindEp;
        if (!parseHostPort(udpBind, bindEp)) {
            std::cerr << "Invalid --udp-bind: " << udpBind << "\n";
            synthDestroy(synth);
            return 1;
        }
        cfg.bindHost = bindEp.host;
        cfg.controlPort = bindEp.port;
        inputThread = startUdpInput(cfg, state, udpSession);
    } else {
        KeyboardInputConfig cfg;
        cfg.devicePath = inputDevice;
        inputThread = startKeyboardInput(cfg, state);
    }

    TerminalInput termInput;
    const bool termOk = termInput.init();

    UdpOutputConfig udpOutCfg;
    udpOutCfg.blockFrames = udpBlockFrames;
    udpOutCfg.channels = 2;

    int outputResult = 0;
    std::thread outputThread([&]() {
        if (outputMode == OutputMode::Soundcard) {
            outputResult = runSoundcardOutput(synth, state, requestedOutputDevice, sampleRate);
        } else if (outputMode == OutputMode::Udp) {
            outputResult = runUdpOutput(synth, state, udpSession, udpOutCfg);
        } else {
            outputResult = runWavOutput(synth, state, wavPath, sampleRate, wavSeconds, 1);
        }
        state.running.store(false, std::memory_order_relaxed);
    });

    const char* inputLabel = "keyboard";
    if (inputSource == InputSource::Midi) {
        inputLabel = "midi";
    } else if (inputSource == InputSource::Udp) {
        inputLabel = "udp";
    }
    const char* outputLabel = "wav";
    if (outputMode == OutputMode::Soundcard) {
        outputLabel = "soundcard";
    } else if (outputMode == OutputMode::Udp) {
        outputLabel = "udp";
    }

    std::cerr << "Input: " << inputLabel
              << " | Output: " << outputLabel
              << " | Press [x] to quit\n";

    while (state.running.load(std::memory_order_relaxed)) {
        if (termOk) {
            const int c = termInput.readChar();
            if (c == 'x' || c == 'X') {
                state.running.store(false, std::memory_order_relaxed);
                break;
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    if (outputThread.joinable()) {
        outputThread.join();
    }
    if (inputThread.joinable()) {
        inputThread.join();
    }

    synthDestroy(synth);

    if (outputMode == OutputMode::Soundcard || listDevicesOnly) {
        Pa_Terminate();
    }

    return outputResult;
}
