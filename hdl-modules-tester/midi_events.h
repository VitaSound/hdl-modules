#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

struct SynthCore;

void synthPostMidiBytes(SynthCore& core, const uint8_t* data, size_t len);
bool synthDrainMidiOut(SynthCore& core, std::vector<uint8_t>& out);
