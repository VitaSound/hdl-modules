#pragma once

#include <cstdint>
#include <vector>

#include "midi_events.h"
#include "shared_state.h"

class Vnoise_box;

struct SynthCore {
    Vnoise_box* top = nullptr;
    uint32_t sampleRate = 48000;
    uint32_t fractional = 0;
};

bool synthInit(SynthCore& core, uint32_t sampleRate);
void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames);
void synthDestroy(SynthCore& core);
