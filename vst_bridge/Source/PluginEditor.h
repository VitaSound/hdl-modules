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
    void updateStatusText();
    juce::Colour linkColour() const;

    HdlVerilatorAudioProcessor& processor_;

    juce::Label titleLabel_;
    juce::Label versionLabel_;
    juce::Label hostLabel_;
    juce::TextEditor hostEditor_;
    juce::Label jitterLabel_;
    juce::Slider jitterSlider_;
    juce::TextButton reconnectButton_{"Reconnect"};
    juce::TextButton playButton_{"Play"};
    juce::TextButton stopButton_{"Stop"};
    juce::TextButton resetStatsButton_{"Reset stats"};
    juce::TextButton testNoteButton_{"Test note OFF"};
    juce::Label statusLabel_;
    juce::Label statsLabel_;
    juce::Label portsLabel_;

    juce::String lastHost_;
    int lastJitterMs_ = -1;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HdlVerilatorAudioProcessorEditor)
};
