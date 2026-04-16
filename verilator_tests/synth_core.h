#pragma once

#include <cstdint>
#include "shared_state.h"

class Vgenerator;

struct SynthCore {
    Vgenerator* top = nullptr;
    uint32_t sampleRate = 48000;
    int channels = 1;
    uint32_t fractional = 0;
};

bool synthInit(SynthCore& core, uint32_t sampleRate, int channels);
void synthGenerate(SynthCore& core, const SharedState& state, int16_t* out, unsigned long frames);
void synthDestroy(SynthCore& core);
