#include "output_wav.h"

#include <chrono>
#include <algorithm>
#include <fstream>
#include <iostream>
#include <thread>
#include <vector>

namespace {
void writeWavHeader(std::ofstream& file, uint32_t sampleRate, uint32_t numSamples, int channels) {
    const uint16_t ch = static_cast<uint16_t>(channels);
    const uint16_t bitsPerSample = 16;
    const uint16_t blockAlign = static_cast<uint16_t>(ch * (bitsPerSample / 8));
    const uint32_t byteRate = sampleRate * blockAlign;
    const uint32_t dataSize = numSamples * blockAlign;
    const uint32_t fileSize = 36 + dataSize;

    file.write("RIFF", 4);
    file.write(reinterpret_cast<const char*>(&fileSize), 4);
    file.write("WAVEfmt ", 8);

    const uint32_t subchunk1Size = 16;
    const uint16_t audioFormat = 1;
    file.write(reinterpret_cast<const char*>(&subchunk1Size), 4);
    file.write(reinterpret_cast<const char*>(&audioFormat), 2);
    file.write(reinterpret_cast<const char*>(&ch), 2);
    file.write(reinterpret_cast<const char*>(&sampleRate), 4);
    file.write(reinterpret_cast<const char*>(&byteRate), 4);
    file.write(reinterpret_cast<const char*>(&blockAlign), 2);
    file.write(reinterpret_cast<const char*>(&bitsPerSample), 2);
    file.write("data", 4);
    file.write(reinterpret_cast<const char*>(&dataSize), 4);
}
} // namespace

int runWavOutput(SynthCore& synth,
                 SharedState& state,
                 const std::string& path,
                 uint32_t sampleRate,
                 uint32_t seconds,
                 int channels) {
    std::ofstream wav(path, std::ios::binary);
    if (!wav.is_open()) {
        std::cerr << "Error: cannot open WAV file for writing: " << path << "\n";
        return 1;
    }

    const uint32_t totalFrames = sampleRate * seconds;
    writeWavHeader(wav, sampleRate, totalFrames, channels);

    synth.sampleRate = sampleRate;
    synth.channels = channels;

    std::vector<int16_t> buffer(256 * channels);
    uint32_t written = 0;
    while (written < totalFrames && state.running.load(std::memory_order_relaxed)) {
        const uint32_t chunkFrames = std::min<uint32_t>(256, totalFrames - written);
        synthGenerate(synth, state, buffer.data(), chunkFrames);
        wav.write(reinterpret_cast<const char*>(buffer.data()), chunkFrames * channels * sizeof(int16_t));
        written += chunkFrames;

        // realtime pacing to keep behavior close to soundcard mode
        std::this_thread::sleep_for(std::chrono::microseconds((1000000ull * chunkFrames) / sampleRate));
    }

    wav.close();
    std::cerr << "WAV written: " << path << " frames=" << written << "\n";
    return 0;
}
