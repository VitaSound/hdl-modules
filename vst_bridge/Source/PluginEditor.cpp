#include "PluginEditor.h"

#include "BuildInfo.h"

namespace {
constexpr int kEditorWidth = 440;
constexpr int kEditorHeight = 352;

void updateTestNoteButtonText(juce::TextButton& button, bool on) {
    button.setButtonText(on ? "Test note ON" : "Test note OFF");
}
} // namespace

HdlVerilatorAudioProcessorEditor::HdlVerilatorAudioProcessorEditor(HdlVerilatorAudioProcessor& p)
    : juce::AudioProcessorEditor(&p), processor_(p) {
    setSize(kEditorWidth, kEditorHeight);

    titleLabel_.setText("HDL Verilator Bridge", juce::dontSendNotification);
    titleLabel_.setFont(juce::FontOptions(18.0f, juce::Font::bold));
    titleLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(titleLabel_);

    versionLabel_.setText("v" HDL_VERILATOR_VERSION " | build " HDL_VERILATOR_BUILD_ID,
                          juce::dontSendNotification);
    versionLabel_.setFont(juce::FontOptions(12.0f));
    versionLabel_.setJustificationType(juce::Justification::centredRight);
    versionLabel_.setColour(juce::Label::textColourId, juce::Colours::lightgrey);
    addAndMakeVisible(versionLabel_);

    hostLabel_.setText("Engine host (IP or hostname)", juce::dontSendNotification);
    hostLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(hostLabel_);

    hostEditor_.setText(processor_.getNetBridge().getEngineHost());
    hostEditor_.setInputRestrictions(64);
    addAndMakeVisible(hostEditor_);

    jitterLabel_.setText("Jitter buffer (ms), recommended 60-120 for UDP", juce::dontSendNotification);
    addAndMakeVisible(jitterLabel_);

    jitterSlider_.setRange(10, 200, 1);
    jitterSlider_.setValue(processor_.getJitterMs());
    jitterSlider_.setTextValueSuffix(" ms");
    addAndMakeVisible(jitterSlider_);

    reconnectButton_.onClick = [this]() {
        applySettings();
        processor_.reconnectEngine();
    };
    addAndMakeVisible(reconnectButton_);

    playButton_.onClick = [this]() {
        applySettings();
        processor_.setBridgeMuted(false);
        processor_.reconnectEngine();
    };
    addAndMakeVisible(playButton_);

    stopButton_.onClick = [this]() { processor_.stopAllNotes(); };
    addAndMakeVisible(stopButton_);

    resetStatsButton_.onClick = [this]() { processor_.resetBridgeStats(); };
    addAndMakeVisible(resetStatsButton_);

    updateTestNoteButtonText(testNoteButton_, processor_.isTestNoteOn());
    testNoteButton_.onClick = [this]() {
        applySettings();
        processor_.setTestNote(!processor_.isTestNoteOn());
        updateTestNoteButtonText(testNoteButton_, processor_.isTestNoteOn());
    };
    addAndMakeVisible(testNoteButton_);

    statusLabel_.setText("Status: starting...", juce::dontSendNotification);
    statusLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(statusLabel_);

    statsLabel_.setText("Buffered: 0 | Underruns: 0", juce::dontSendNotification);
    statsLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(statsLabel_);

    portsLabel_.setText("UDP 5004/5005 | native engine: 127.0.0.1 | block 512-1024",
                        juce::dontSendNotification);
    portsLabel_.setFont(juce::FontOptions(11.0f));
    portsLabel_.setJustificationType(juce::Justification::centredLeft);
    portsLabel_.setColour(juce::Label::textColourId, juce::Colours::grey);
    addAndMakeVisible(portsLabel_);

    lastHost_ = processor_.getNetBridge().getEngineHost();
    lastJitterMs_ = static_cast<int>(jitterSlider_.getValue());

    startTimerHz(4);
}

HdlVerilatorAudioProcessorEditor::~HdlVerilatorAudioProcessorEditor() = default;

void HdlVerilatorAudioProcessorEditor::paint(juce::Graphics& g) {
    g.fillAll(getLookAndFeel().findColour(juce::ResizableWindow::backgroundColourId));

    const auto dot = linkColour();
    g.setColour(dot);
    g.fillEllipse(14.0f, static_cast<float>(getHeight() - 34), 10.0f, 10.0f);
}

juce::Colour HdlVerilatorAudioProcessorEditor::linkColour() const {
    const auto& bridge = processor_.getNetBridge();
    if (bridge.isPrimed() && bridge.getBufferedSamples() > 0) {
        return juce::Colours::limegreen;
    }
    if (bridge.isConnected()) {
        return juce::Colours::orange;
    }
    return juce::Colours::indianred;
}

void HdlVerilatorAudioProcessorEditor::resized() {
    auto area = getLocalBounds().reduced(14);

    auto header = area.removeFromTop(28);
    titleLabel_.setBounds(header.removeFromLeft(header.getWidth() * 2 / 3));
    versionLabel_.setBounds(header);

    area.removeFromTop(8);
    hostLabel_.setBounds(area.removeFromTop(18));
    area.removeFromTop(4);
    hostEditor_.setBounds(area.removeFromTop(28));

    area.removeFromTop(10);
    jitterLabel_.setBounds(area.removeFromTop(18));
    area.removeFromTop(4);
    jitterSlider_.setBounds(area.removeFromTop(28));

    area.removeFromTop(12);
    auto buttons = area.removeFromTop(30);
    const int gap = 8;
    const int buttonWidth = (buttons.getWidth() - gap * 3) / 4;
    reconnectButton_.setBounds(buttons.removeFromLeft(buttonWidth));
    buttons.removeFromLeft(gap);
    playButton_.setBounds(buttons.removeFromLeft(buttonWidth));
    buttons.removeFromLeft(gap);
    stopButton_.setBounds(buttons.removeFromLeft(buttonWidth));
    buttons.removeFromLeft(gap);
    resetStatsButton_.setBounds(buttons);

    area.removeFromTop(8);
    testNoteButton_.setBounds(area.removeFromTop(30));

    area.removeFromTop(12);
    statusLabel_.setBounds(area.removeFromTop(20).withTrimmedLeft(18));
    statsLabel_.setBounds(area.removeFromTop(20).withTrimmedLeft(18));
    portsLabel_.setBounds(area.removeFromTop(18).withTrimmedLeft(18));
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

void HdlVerilatorAudioProcessorEditor::updateStatusText() {
    const auto& bridge = processor_.getNetBridge();
    juce::String status;
    if (bridge.isMuted()) {
        status = "Status: MUTED - click Play (Stop silences output)";
    } else if (bridge.isPrimed() && bridge.getBufferedSamples() > 0) {
        status = "Status: streaming PCM from engine";
    } else if (bridge.isConnected()) {
        status = "Status: connected, filling jitter buffer";
    } else if (bridge.getBufferedSamples() > 0) {
        status = "Status: receiving PCM (no ACK yet)";
    } else {
        status = "Status: waiting for engine - check IP, WSL, firewall";
    }
    statusLabel_.setText(status, juce::dontSendNotification);
}

void HdlVerilatorAudioProcessorEditor::timerCallback() {
    applySettings();
    updateStatusText();

    const auto& bridge = processor_.getNetBridge();
    const int buffered = bridge.getBufferedSamples();
    const int target = bridge.getTargetBufferSamples();
    statsLabel_.setText("Buffered: " + juce::String(buffered) + " / " + juce::String(target) +
                            " target | Underruns: " + juce::String(bridge.getUnderruns()) +
                            (bridge.isMuted() ? " | muted" : ""),
                        juce::dontSendNotification);

    playButton_.setEnabled(bridge.isMuted());
    stopButton_.setEnabled(!bridge.isMuted());
    updateTestNoteButtonText(testNoteButton_, processor_.isTestNoteOn());
    repaint();
}
