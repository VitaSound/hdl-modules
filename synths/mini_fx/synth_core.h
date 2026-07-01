#pragma once

#include <cstdint>
#include <vector>

#include "midi_decode.h"
#include "midi_events.h"
#include "shared_state.h"

class Vmini_fx;

struct SynthCore {
    Vmini_fx* top = nullptr;
    uint32_t sampleRate = 44100;
    uint32_t fractional = 0;
    bool midiLog = false;
    MidiDecodeState midiDecode{};
    std::vector<uint8_t> pendingMidiBytes;
    std::vector<uint8_t> midiOutBytes;
};

bool synthInit(SynthCore& core, uint32_t sampleRate);
void synthPostMidiBytes(SynthCore& core, const uint8_t* data, size_t len);
void synthOnSessionStart(SynthCore& core);
bool synthDrainMidiOut(SynthCore& core, std::vector<uint8_t>& out);
void synthGeneratePull(SynthCore& core,
                       const SharedState& state,
                       int16_t* mono,
                       unsigned long frames,
                       const int16_t* mono_in);
void synthDestroy(SynthCore& core);
