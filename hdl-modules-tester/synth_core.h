#pragma once

#include <cstdint>

#include "shared_state.h"

class Vgenerator;

// Verilog synth stepped only on AudioPull from VST host (no wall-clock audio loop).
struct SynthCore {
    Vgenerator* top = nullptr;
    uint32_t sampleRate = 48000;
    uint32_t fractional = 0;
};

bool synthInit(SynthCore& core, uint32_t sampleRate);
void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames);
void synthDestroy(SynthCore& core);
