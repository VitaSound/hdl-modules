#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"

class HdlVerilatorAudioProcessorEditor : public juce::AudioProcessorEditor,
                                         private juce::Timer {
public:
    explicit HdlVerilatorAudioProcessorEditor(HdlVerilatorAudioProcessor&);
    ~HdlVerilatorAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;

private:
    void timerCallback() override;
    void applySettings();

    HdlVerilatorAudioProcessor& processor_;

    juce::Label titleLabel_;
    juce::Label statusLabel_;
    juce::Label statsLabel_;
    juce::TextEditor hostEditor_;
    juce::Slider jitterSlider_;
    juce::Label jitterLabel_;

    juce::String lastHost_;
    int lastJitterMs_ = -1;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HdlVerilatorAudioProcessorEditor)
};
