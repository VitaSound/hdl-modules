#include "output_soundcard.h"

#include <chrono>
#include <iostream>
#include <thread>

namespace {
struct SoundcardCallbackContext {
    SynthCore* synth = nullptr;
    SharedState* state = nullptr;
};

int audioCallback(const void*,
                  void* output,
                  unsigned long frameCount,
                  const PaStreamCallbackTimeInfo*,
                  PaStreamCallbackFlags,
                  void* userData) {
    auto* ctx = static_cast<SoundcardCallbackContext*>(userData);
    auto* out = static_cast<int16_t*>(output);
    synthGenerate(*ctx->synth, *ctx->state, out, frameCount);

    if (!ctx->state->running.load(std::memory_order_relaxed)) {
        return paComplete;
    }
    return paContinue;
}
} // namespace

std::vector<OutputDeviceInfo> listOutputDevices() {
    std::vector<OutputDeviceInfo> devices;
    const int count = Pa_GetDeviceCount();
    if (count < 0) {
        return devices;
    }

    for (int i = 0; i < count; ++i) {
        const PaDeviceInfo* d = Pa_GetDeviceInfo(i);
        if (!d || d->maxOutputChannels <= 0) {
            continue;
        }
        const PaHostApiInfo* api = Pa_GetHostApiInfo(d->hostApi);
        OutputDeviceInfo info;
        info.index = i;
        info.name = d->name;
        info.api = api ? api->name : "unknown";
        info.maxChannels = d->maxOutputChannels;
        info.defaultSampleRate = d->defaultSampleRate;
        devices.push_back(info);
    }

    return devices;
}

bool outputDeviceSupportsFormat(PaDeviceIndex device, int channels, double sampleRate) {
    PaStreamParameters outputParameters;
    outputParameters.device = device;
    outputParameters.channelCount = channels;
    outputParameters.sampleFormat = paInt16;
    outputParameters.suggestedLatency = Pa_GetDeviceInfo(device)->defaultLowOutputLatency;
    outputParameters.hostApiSpecificStreamInfo = nullptr;
    return Pa_IsFormatSupported(nullptr, &outputParameters, sampleRate) == paFormatIsSupported;
}

int runSoundcardOutput(SynthCore& synth, SharedState& state, PaDeviceIndex device, uint32_t sampleRate) {
    const PaDeviceInfo* deviceInfo = Pa_GetDeviceInfo(device);
    if (!deviceInfo || deviceInfo->maxOutputChannels <= 0) {
        std::cerr << "Invalid output device index " << device << "\n";
        return 1;
    }

    const int channels = deviceInfo->maxOutputChannels >= 2 ? 2 : 1;
    const PaHostApiInfo* hostInfo = Pa_GetHostApiInfo(deviceInfo->hostApi);

    PaStreamParameters outputParameters;
    outputParameters.device = device;
    outputParameters.channelCount = channels;
    outputParameters.sampleFormat = paInt16;
    outputParameters.suggestedLatency = deviceInfo->defaultLowOutputLatency;
    outputParameters.hostApiSpecificStreamInfo = nullptr;

    double openSampleRate = sampleRate;
    PaError err = Pa_IsFormatSupported(nullptr, &outputParameters, openSampleRate);
    if (err != paFormatIsSupported) {
        openSampleRate = deviceInfo->defaultSampleRate;
        err = Pa_IsFormatSupported(nullptr, &outputParameters, openSampleRate);
        if (err != paFormatIsSupported) {
            std::cerr << "PortAudio format error: " << Pa_GetErrorText(err) << "\n";
            return 1;
        }
    }

    synth.sampleRate = static_cast<uint32_t>(openSampleRate);
    synth.channels = channels;

    SoundcardCallbackContext cbCtx{&synth, &state};
    PaStream* stream = nullptr;
    err = Pa_OpenStream(&stream,
                        nullptr,
                        &outputParameters,
                        openSampleRate,
                        paFramesPerBufferUnspecified,
                        paClipOff,
                        audioCallback,
                        &cbCtx);
    if (err != paNoError) {
        std::cerr << "PortAudio error: " << Pa_GetErrorText(err) << "\n";
        return 1;
    }

    err = Pa_StartStream(stream);
    if (err != paNoError) {
        std::cerr << "PortAudio error: " << Pa_GetErrorText(err) << "\n";
        Pa_CloseStream(stream);
        return 1;
    }

    std::cerr << "Output soundcard: device=[" << device << "] " << deviceInfo->name
              << " api=" << (hostInfo ? hostInfo->name : "unknown")
              << " sample_rate=" << synth.sampleRate
              << " channels=" << synth.channels << "\n";

    while (state.running.load(std::memory_order_relaxed) && Pa_IsStreamActive(stream) == 1) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    err = Pa_StopStream(stream);
    if (err != paNoError) {
        std::cerr << "PortAudio error: " << Pa_GetErrorText(err) << "\n";
    }
    Pa_CloseStream(stream);
    return 0;
}
