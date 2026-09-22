#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "midi_decode.h"
#include "midi_events.h"
#include "shared_state.h"

#include "../wave_trace.h"

class Vnoise_box;

struct SynthCore {
    Vnoise_box* top = nullptr;
    uint32_t sampleRate = 48000;
    uint32_t fractional = 0;
    MidiDecodeState midiDecode{};
    std::vector<uint8_t> pendingMidiBytes;
    std::vector<uint8_t> midiOutBytes;
    WaveTrace trace;
};

bool synthInit(SynthCore& core, uint32_t sampleRate);
void synthOnSessionStart(SynthCore& core);
void synthResetPullTiming(SynthCore& core);
void synthSetSampleRate(SynthCore& core, uint32_t sampleRate);
uint32_t synthGetSampleRate(const SynthCore& core);
void synthPostMidiBytes(SynthCore& core, const uint8_t* data, size_t len);
bool synthDrainMidiOut(SynthCore& core, std::vector<uint8_t>& out);
void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames,
                       const int16_t* mono_in = nullptr);
void synthDestroy(SynthCore& core);

bool synthTraceOpen(SynthCore& core, const std::string& path, uint64_t max_frames);
void synthTraceClose(SynthCore& core);
