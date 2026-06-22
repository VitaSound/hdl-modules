#pragma once

#include <cstdint>
#include <vector>

#include "midi_decode.h"
#include "midi_events.h"
#include "shared_state.h"

class Vmono_synth;

struct SynthCore {
    Vmono_synth* top = nullptr;
    uint32_t sampleRate = 48000;
    uint32_t fractional = 0;
    bool midiLog = false;
    MidiDecodeState midiDecode{};
    std::vector<uint8_t> pendingMidiBytes;
    std::vector<uint8_t> midiOutBytes;
};

bool synthInit(SynthCore& core, uint32_t sampleRate);
void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames);
void synthDestroy(SynthCore& core);
