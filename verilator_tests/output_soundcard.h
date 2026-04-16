#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include <portaudio.h>

#include "shared_state.h"
#include "synth_core.h"

struct OutputDeviceInfo {
    int index = -1;
    std::string name;
    std::string api;
    int maxChannels = 0;
    double defaultSampleRate = 0.0;
};

std::vector<OutputDeviceInfo> listOutputDevices();
bool outputDeviceSupportsFormat(PaDeviceIndex device, int channels, double sampleRate);
int runSoundcardOutput(SynthCore& synth, SharedState& state, PaDeviceIndex device, uint32_t sampleRate);
