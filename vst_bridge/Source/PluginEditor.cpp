#include "PluginEditor.h"

HdlVerilatorAudioProcessorEditor::HdlVerilatorAudioProcessorEditor(HdlVerilatorAudioProcessor& p)
    : juce::AudioProcessorEditor(&p), processor_(p) {
    setSize(420, 220);

    titleLabel_.setText("HDL Verilator Bridge", juce::dontSendNotification);
    titleLabel_.setFont(juce::FontOptions(18.0f, juce::Font::bold));
    titleLabel_.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(titleLabel_);

    statusLabel_.setText("Status: starting...", juce::dontSendNotification);
    statusLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(statusLabel_);

    statsLabel_.setText("Buffered: 0 | Underruns: 0", juce::dontSendNotification);
    statsLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(statsLabel_);

    hostEditor_.setText(processor_.getNetBridge().getEngineHost());
    hostEditor_.setInputRestrictions(64);
    addAndMakeVisible(hostEditor_);

    jitterLabel_.setText("Jitter buffer (ms)", juce::dontSendNotification);
    addAndMakeVisible(jitterLabel_);

    jitterSlider_.setRange(10, 200, 1);
    jitterSlider_.setValue(40);
    jitterSlider_.setTextValueSuffix(" ms");
    addAndMakeVisible(jitterSlider_);

    lastHost_ = processor_.getNetBridge().getEngineHost();
    lastJitterMs_ = 40;

    startTimerHz(4);
}

HdlVerilatorAudioProcessorEditor::~HdlVerilatorAudioProcessorEditor() = default;

void HdlVerilatorAudioProcessorEditor::paint(juce::Graphics& g) {
    g.fillAll(getLookAndFeel().findColour(juce::ResizableWindow::backgroundColourId));
    g.setColour(juce::Colours::white);
    g.drawFittedText("Engine host (IP or hostname)", getLocalBounds().reduced(12).removeFromTop(60),
                     juce::Justification::bottomLeft, 1);
}

void HdlVerilatorAudioProcessorEditor::resized() {
    auto area = getLocalBounds().reduced(12);
    titleLabel_.setBounds(area.removeFromTop(28));
    area.removeFromTop(28);
    hostEditor_.setBounds(area.removeFromTop(28));
    area.removeFromTop(8);
    jitterLabel_.setBounds(area.removeFromTop(20));
    jitterSlider_.setBounds(area.removeFromTop(28));
    area.removeFromTop(8);
    statusLabel_.setBounds(area.removeFromTop(22));
    statsLabel_.setBounds(area.removeFromTop(22));
}

void HdlVerilatorAudioProcessorEditor::applySettings() {
    const auto host = hostEditor_.getText().trim();
    const int jitter = static_cast<int>(jitterSlider_.getValue());
    if (host != lastHost_) {
        lastHost_ = host;
        processor_.setEngineHost(host);
    }
    if (jitter != lastJitterMs_) {
        lastJitterMs_ = jitter;
        processor_.getNetBridge().setJitterMs(jitter);
    }
}

void HdlVerilatorAudioProcessorEditor::timerCallback() {
    applySettings();
    const auto& bridge = processor_.getNetBridge();
    const bool linked = bridge.isConnected();
    statusLabel_.setText(linked ? "Status: connected to engine"
                                : "Status: waiting for engine ACK",
                         juce::dontSendNotification);
    statsLabel_.setText("Buffered: " + juce::String(bridge.getBufferedSamples()) + " / " +
                            juce::String(bridge.getWarmupBufferSamples()) + " warmup | Underruns: " +
                            juce::String(bridge.getUnderruns()),
                        juce::dontSendNotification);
}
