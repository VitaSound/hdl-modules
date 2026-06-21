#pragma once

#include <cstdint>
#include <string>

#include "shared_state.h"

struct SynthCore;

int runWavOutput(SynthCore& synth,
                 SharedState& state,
                 const std::string& path,
                 uint32_t sampleRate,
                 uint32_t seconds,
                 int channels = 1);
