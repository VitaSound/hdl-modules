#pragma once

#include <functional>
#include <vector>

#include <JuceHeader.h>
#include "hdl_net.h"

struct SynthParam {
    juce::String id;
    juce::String name;
    juce::String group;
    juce::String type;
    int cc = -1;
    int ccMsb = -1;
    int ccLsb = -1;
    int defaultValue = 0;
    int minValue = 0;
    int maxValue = 127;
    juce::StringArray choices;
    std::vector<int> midiValues;
};

struct SynthParamSchema {
    juce::String synthId = "fallback";
    juce::String title = "Fallback";
    juce::String source = "fallback";
    uint32_t hash = 0;
    int midiChannel = 1;
    std::vector<SynthParam> params;
};

SynthParamSchema loadRuntimeSynthParamSchema(const juce::String& host, uint16_t port);
juce::String loadCachedSynthParamHost();
void saveCachedSynthParamHost(const juce::String& host);
juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout(const SynthParamSchema& schema);
void sendParamAsMidi(const SynthParamSchema& schema,
                     juce::AudioProcessorValueTreeState& apvts,
                     const juce::String& paramId,
                     float normalizedValue,
                     const std::function<void(const std::vector<uint8_t>&)>& sendBytes);
const SynthParam* findSynthParam(const SynthParamSchema& schema, const juce::String& paramId);
