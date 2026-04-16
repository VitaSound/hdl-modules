#include "Vgenerator.h"
#include "verilated.h"
#include <portaudio.h>
#include <atomic>
#include <cstdint>
#include <csignal>
#include <cerrno>
#include <fstream>
#include <iostream>
#include <thread>
#include <chrono>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/input.h>
#include <string>
#include <vector>
#include <cstring>

namespace {
constexpr uint32_t DEFAULT_SAMPLE_RATE = 48000;
constexpr uint32_t VERILOG_CLK_HZ = 1000000;
constexpr unsigned long FRAMES_PER_BUFFER = paFramesPerBufferUnspecified;

std::atomic<bool> g_running(true);
std::atomic<bool> g_gate(false);
std::atomic<int> g_note(-1);
std::atomic<bool> g_evdev_active(false);
} // namespace

// Запись заголовка WAV
void writeWavHeader(std::ofstream& file, uint32_t sampleRate, uint32_t numSamples) {
    file.write("RIFF", 4);
    uint32_t fileSize = 36 + numSamples * 2;
    file.write((char*)&fileSize, 4);
    file.write("WAVEfmt ", 8);
    uint32_t subchunk1Size = 16;
    file.write((char*)&subchunk1Size, 4);
    uint16_t audioFormat = 1; // PCM
    file.write((char*)&audioFormat, 2);
    uint16_t numChannels = 1; // Моно
    file.write((char*)&numChannels, 2);
    file.write((char*)&sampleRate, 4);
    uint32_t byteRate = sampleRate * 2; // 16-bit PCM
    file.write((char*)&byteRate, 4);
    uint16_t blockAlign = 2;
    file.write((char*)&blockAlign, 2);
    uint16_t bitsPerSample = 16;
    file.write((char*)&bitsPerSample, 2);
    file.write("data", 4);
    uint32_t dataSize = numSamples * 2;
    file.write((char*)&dataSize, 4);
}

struct AudioContext {
    Vgenerator* top = nullptr;
    std::ofstream wavFile;
    uint32_t samplesWritten = 0;
    uint32_t fractional = 0;
    uint32_t sampleRate = DEFAULT_SAMPLE_RATE;
    int channels = 1;
    bool recordWav = true;
};

void stepVerilogCycles(Vgenerator* top, uint32_t cycles) {
    for (uint32_t i = 0; i < cycles; ++i) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
}

void onSignal(int) {
    g_running = false;
}

int audioCallback(const void*,
                  void* output,
                  unsigned long frameCount,
                  const PaStreamCallbackTimeInfo*,
                  PaStreamCallbackFlags,
                  void* userData) {
    auto* ctx = static_cast<AudioContext*>(userData);
    int16_t* out = static_cast<int16_t*>(output);

    const bool enabled = g_gate.load(std::memory_order_relaxed);
    ctx->top->enable = enabled ? 1 : 0;

    for (unsigned long i = 0; i < frameCount; ++i) {
        // Точное целочисленное соотношение 1_000_000 -> 48_000:
        // на каждый аудио-сэмпл идем на 20 или 21 такт Verilog.
        ctx->fractional += VERILOG_CLK_HZ;
        uint32_t cycles = ctx->fractional / ctx->sampleRate;
        ctx->fractional %= ctx->sampleRate;
        stepVerilogCycles(ctx->top, cycles);

        int16_t sample = ctx->top->audio_out ? 12000 : -12000;
        if (ctx->channels == 2) {
            out[i * 2 + 0] = sample;
            out[i * 2 + 1] = sample;
        } else {
            out[i] = sample;
        }

        if (ctx->recordWav && ctx->wavFile.is_open()) {
            ctx->wavFile.write((char*)&sample, 2);
            ctx->samplesWritten++;
        }
    }

    if (!g_running.load()) {
        return paComplete;
    }
    return paContinue;
}

class TerminalInput {
public:
    bool init() {
        fd_ = STDIN_FILENO;
        if (!isatty(fd_)) {
            std::cerr << "STDIN is not a TTY, keyboard control disabled.\n";
            return false;
        }

        if (tcgetattr(fd_, &oldTerm_) != 0) {
            perror("tcgetattr");
            return false;
        }
        termios raw = oldTerm_;
        raw.c_lflag &= static_cast<unsigned>(~(ICANON | ECHO));
        raw.c_cc[VMIN] = 0;
        raw.c_cc[VTIME] = 0;
        if (tcsetattr(fd_, TCSANOW, &raw) != 0) {
            perror("tcsetattr");
            return false;
        }

        oldFlags_ = fcntl(fd_, F_GETFL, 0);
        if (oldFlags_ >= 0) {
            (void)fcntl(fd_, F_SETFL, oldFlags_ | O_NONBLOCK);
        }

        active_ = true;
        return true;
    }

    int readChar() const {
        if (!active_) {
            return -1;
        }
        unsigned char c = 0;
        ssize_t n = ::read(fd_, &c, 1);
        if (n == 1) {
            return static_cast<int>(c);
        }
        return -1;
    }

    ~TerminalInput() {
        if (!active_) {
            return;
        }
        if (oldFlags_ >= 0) {
            (void)fcntl(fd_, F_SETFL, oldFlags_);
        }
        (void)tcsetattr(fd_, TCSANOW, &oldTerm_);
    }

private:
    int fd_ = -1;
    int oldFlags_ = -1;
    termios oldTerm_{};
    bool active_ = false;
};

void keyboardEventLoop(const std::string& devicePath) {
    int fd = open(devicePath.c_str(), O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
        std::cerr << "Cannot open input device " << devicePath
                  << " (need read permission): " << strerror(errno) << "\n";
        std::cerr << "No evdev input -> GATE stays 0.\n";
        return;
    }

    g_evdev_active = true;
    std::cout << "Keyboard gate device: " << devicePath
              << " (notes: qwertyu)\n";

    const auto keyToNote = [](uint16_t code) -> int {
        switch (code) {
            case KEY_Q: return 0;
            case KEY_W: return 1;
            case KEY_E: return 2;
            case KEY_R: return 3;
            case KEY_T: return 4;
            case KEY_Y: return 5;
            case KEY_U: return 6;
            default: return -1;
        }
    };

    const auto keyName = [](uint16_t code) -> const char* {
        switch (code) {
            case KEY_Q: return "Q";
            case KEY_W: return "W";
            case KEY_E: return "E";
            case KEY_R: return "R";
            case KEY_T: return "T";
            case KEY_Y: return "Y";
            case KEY_U: return "U";
            default: return "?";
        }
    };

    const auto evValueName = [](int v) -> const char* {
        if (v == 0) return "up";
        if (v == 1) return "down";
        if (v == 2) return "repeat";
        return "unknown";
    };

    const auto firstNoteFromMask = [](uint8_t mask) -> int {
        for (int i = 0; i < 7; ++i) {
            if (mask & (1u << i)) {
                return i;
            }
        }
        return -1;
    };

    input_event ev{};
    uint8_t pressedNotesMask = 0;
    while (g_running.load()) {
        ssize_t n = read(fd, &ev, sizeof(ev));
        if (n == static_cast<ssize_t>(sizeof(ev))) {
            if (ev.type == EV_KEY) {
                const int note = keyToNote(ev.code);
                if (note >= 0) {
                    const uint8_t bit = static_cast<uint8_t>(1u << note);
                    if (ev.value == 1) {
                        g_note.store(note, std::memory_order_relaxed);
                        pressedNotesMask = static_cast<uint8_t>(pressedNotesMask | bit);
                    } else if (ev.value == 2) {
                        // autorepeat: состояние зажатия уже выставлено на key-down
                    } else if (ev.value == 0) {
                        pressedNotesMask = static_cast<uint8_t>(pressedNotesMask & ~bit);
                        g_note.store(firstNoteFromMask(pressedNotesMask), std::memory_order_relaxed);
                    }
                    g_gate.store(pressedNotesMask != 0, std::memory_order_relaxed);

                    std::cerr << "[evdev] key=" << keyName(ev.code)
                              << " note=" << note
                              << " event=" << evValueName(ev.value)
                              << " mask=0x" << std::hex << static_cast<int>(pressedNotesMask) << std::dec
                              << " gate=" << (g_gate.load(std::memory_order_relaxed) ? 1 : 0)
                              << " active_note=" << g_note.load(std::memory_order_relaxed)
                              << "\n";
                    std::cerr.flush();
                }
            }
            continue;
        }

        if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
            std::cerr << "Read error from " << devicePath << ": " << strerror(errno) << "\n";
            break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }

    close(fd);
    g_evdev_active = false;
    g_gate.store(false, std::memory_order_relaxed);
    g_note.store(-1, std::memory_order_relaxed);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    std::signal(SIGINT, onSignal);
    std::signal(SIGTERM, onSignal);

    std::string inputDevice = "/dev/input/event2";
    PaDeviceIndex requestedOutputDevice = paNoDevice;
    uint32_t requestedSampleRate = DEFAULT_SAMPLE_RATE;
    bool listDevicesOnly = false;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--input-device" && i + 1 < argc) {
            inputDevice = argv[++i];
        } else if (arg == "--device-index" && i + 1 < argc) {
            requestedOutputDevice = static_cast<PaDeviceIndex>(std::stoi(argv[++i]));
        } else if (arg == "--sample-rate" && i + 1 < argc) {
            requestedSampleRate = static_cast<uint32_t>(std::stoul(argv[++i]));
        } else if (arg == "--list-devices") {
            listDevicesOnly = true;
        }
    }

    AudioContext ctx;
    ctx.top = new Vgenerator;
    ctx.top->clk = 0;
    ctx.top->enable = 0;
    ctx.top->eval();

    PaError err = Pa_Initialize();
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    const int deviceCount = Pa_GetDeviceCount();
    if (deviceCount < 0) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(deviceCount));
        Pa_Terminate();
        return 1;
    }
    std::vector<PaDeviceIndex> outputDevices;
    std::cerr << "PortAudio output devices:\n";
    for (PaDeviceIndex i = 0; i < deviceCount; ++i) {
        const PaDeviceInfo* d = Pa_GetDeviceInfo(i);
        if (!d || d->maxOutputChannels <= 0) {
            continue;
        }
        outputDevices.push_back(i);
        const PaHostApiInfo* api = Pa_GetHostApiInfo(d->hostApi);
        std::cerr << "  [" << i << "] " << d->name
                  << " | api=" << (api ? api->name : "unknown")
                  << " | out_ch=" << d->maxOutputChannels
                  << " | default_sr=" << d->defaultSampleRate << "\n";
    }
    if (outputDevices.empty()) {
        std::cerr << "No output devices found.\n";
        Pa_Terminate();
        return 1;
    }
    if (listDevicesOnly) {
        Pa_Terminate();
        return 0;
    }

    if (requestedOutputDevice == paNoDevice) {
        std::cerr << "Enter output device index: ";
        std::cerr.flush();
        int index = -1;
        if (!(std::cin >> index)) {
            std::cerr << "Invalid input.\n";
            Pa_Terminate();
            return 1;
        }
        requestedOutputDevice = static_cast<PaDeviceIndex>(index);
    }

    PaDeviceIndex outputDevice = (requestedOutputDevice != paNoDevice)
                                     ? requestedOutputDevice
                                     : Pa_GetDefaultOutputDevice();
    if (outputDevice == paNoDevice) {
        fprintf(stderr, "PortAudio error: default output device not found.\n");
        Pa_Terminate();
        return 1;
    }
    if (outputDevice < 0 || outputDevice >= deviceCount) {
        fprintf(stderr, "PortAudio error: invalid output device index %d.\n", outputDevice);
        Pa_Terminate();
        return 1;
    }
    const PaDeviceInfo* deviceInfo = Pa_GetDeviceInfo(outputDevice);
    if (!deviceInfo || deviceInfo->maxOutputChannels <= 0) {
        fprintf(stderr, "PortAudio error: selected device has no output channels.\n");
        Pa_Terminate();
        return 1;
    }
    const PaHostApiInfo* hostInfo = Pa_GetHostApiInfo(deviceInfo->hostApi);

    PaStreamParameters outputParameters;
    outputParameters.device = outputDevice;
    outputParameters.channelCount = deviceInfo->maxOutputChannels >= 2 ? 2 : 1;
    outputParameters.sampleFormat = paInt16;
    outputParameters.suggestedLatency = deviceInfo->defaultLowOutputLatency;
    outputParameters.hostApiSpecificStreamInfo = nullptr;

    double openSampleRate = requestedSampleRate;
    err = Pa_IsFormatSupported(nullptr, &outputParameters, openSampleRate);
    if (err != paFormatIsSupported) {
        const double fallbackRate = deviceInfo->defaultSampleRate;
        std::cerr << "Requested format unsupported (" << requestedSampleRate
                  << " Hz, ch=" << outputParameters.channelCount
                  << "). Trying device default " << fallbackRate << " Hz.\n";
        err = Pa_IsFormatSupported(nullptr, &outputParameters, fallbackRate);
        if (err != paFormatIsSupported) {
            std::cerr << "PortAudio format error: " << Pa_GetErrorText(err) << "\n";
            Pa_Terminate();
            return 1;
        }
        openSampleRate = fallbackRate;
    }

    PaStream* stream;
    err = Pa_OpenStream(&stream,
                        nullptr,
                        &outputParameters,
                        openSampleRate,
                        FRAMES_PER_BUFFER,
                        paClipOff,
                        audioCallback,
                        &ctx);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        Pa_Terminate();
        return 1;
    }

    if (ctx.recordWav) {
        ctx.wavFile.open("output.wav", std::ios::binary);
    }
    if (ctx.recordWav && !ctx.wavFile.is_open()) {
        fprintf(stderr, "Error: Could not open output.wav for writing.\n");
        Pa_CloseStream(stream);
        Pa_Terminate();
        return 1;
    }
    if (ctx.recordWav) {
        writeWavHeader(ctx.wavFile, static_cast<uint32_t>(openSampleRate), 0);
    }

    ctx.sampleRate = static_cast<uint32_t>(openSampleRate);
    ctx.channels = outputParameters.channelCount;

    err = Pa_StartStream(stream);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        Pa_CloseStream(stream);
        Pa_Terminate();
        return 1;
    }

    TerminalInput termInput;
    const bool keyboardOk = termInput.init();
    std::thread keyThread(keyboardEventLoop, inputDevice);
    std::cerr << "Realtime audio started: device=[" << outputDevice << "] "
              << deviceInfo->name
              << " api=" << (hostInfo ? hostInfo->name : "unknown")
              << " sample_rate=" << ctx.sampleRate
              << " channels=" << ctx.channels << "\n";
    if (keyboardOk) {
        std::cerr << "Keys: [x] quit.\n";
        std::cerr << "evdev notes: [qwertyu], gate=1 while key is held.\n";
    }
    std::cerr.flush();

    while (g_running.load() && Pa_IsStreamActive(stream) == 1) {
        if (keyboardOk) {
            const int c = termInput.readChar();
            if (c == 'x' || c == 'X') {
                g_running = false;
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    g_running = false;
    keyThread.join();

    err = Pa_StopStream(stream);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
    }
    Pa_CloseStream(stream);

    if (ctx.recordWav && ctx.wavFile.is_open()) {
        ctx.wavFile.seekp(0, std::ios::beg);
        writeWavHeader(ctx.wavFile, ctx.sampleRate, ctx.samplesWritten);
        ctx.wavFile.close();
    }

    Pa_Terminate();
    delete ctx.top;
    return 0;
}
