#include "PluginEditor.h"

#include "BuildInfo.h"

namespace {
constexpr int kEditorWidth = 520;
constexpr int kEditorHeight = 920;
constexpr int kSynthPanelHeight = 340;
} // namespace

HdlVerilatorAudioProcessorEditor::HdlVerilatorAudioProcessorEditor(HdlVerilatorAudioProcessor& p)
    : juce::AudioProcessorEditor(&p),
      processor_(p),
      synthEditor_(std::make_unique<juce::GenericAudioProcessorEditor>(p)) {
    setSize(kEditorWidth, kEditorHeight);
    addAndMakeVisible(*synthEditor_);

    titleLabel_.setText("VitaSound Remote Synth", juce::dontSendNotification);
    titleLabel_.setFont(juce::FontOptions(18.0f, juce::Font::bold));
    titleLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(titleLabel_);

    versionLabel_.setText("v" HDL_VERILATOR_VERSION " | " HDL_VERILATOR_GIT_REV " | " HDL_VERILATOR_BUILD_ID,
                          juce::dontSendNotification);
    versionLabel_.setFont(juce::FontOptions(10.0f));
    versionLabel_.setJustificationType(juce::Justification::centredRight);
    versionLabel_.setColour(juce::Label::textColourId, juce::Colours::lightgrey);
    addAndMakeVisible(versionLabel_);

    hostLabel_.setText("Engine host (IP or hostname)", juce::dontSendNotification);
    hostLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(hostLabel_);

    addAndMakeVisible(connectionIndicator_);

    hostEditor_.setText(processor_.getNetBridge().getEngineHost());
    hostEditor_.setInputRestrictions(64);
    addAndMakeVisible(hostEditor_);

    reconnectButton_.onClick = [this]() {
        applySettings();
        resumePlayWhenConnected_ = true;
        lastConnected_ = false;
        processor_.reconnectEngine();
    };
    addAndMakeVisible(reconnectButton_);

    auto setupPacketSlider = [this](juce::Label& label, juce::Slider& slider, const juce::String& text,
                                    int value) {
        label.setText(text, juce::dontSendNotification);
        addAndMakeVisible(label);
        slider.setRange(2, 24, 1);
        slider.setValue(value);
        slider.setTextValueSuffix(" pkt");
        slider.setSliderStyle(juce::Slider::LinearHorizontal);
        slider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 52, 22);
        addAndMakeVisible(slider);
    };

    auto& bridge = processor_.getNetBridge();
    setupPacketSlider(minReserveLabel_, minReserveSlider_, "Min reserve (packets)", bridge.getMinReservePackets());
    setupPacketSlider(targetReserveLabel_, targetReserveSlider_, "Target reserve (packets)",
                      bridge.getTargetReservePackets());
    setupPacketSlider(warmupLabel_, warmupSlider_, "Initial warmup (packets)", bridge.getInitialWarmupPackets());

    profileLabel_.setText("Network profile (starting packet reserves)", juce::dontSendNotification);
    addAndMakeVisible(profileLabel_);
    profileCombo_.addItem("Auto (from host IP)", 1);
    profileCombo_.addItem("WSL (172.x, bursty NAT)", 2);
    profileCombo_.addItem("Local (127.0.0.1, same PC)", 3);
    profileCombo_.addItem("LAN / Wi-Fi (other IP)", 4);
    profileCombo_.setSelectedId(static_cast<int>(bridge.getNetworkProfile()) + 1, juce::dontSendNotification);
    profileCombo_.onChange = [this]() { applySettings(); };
    addAndMakeVisible(profileCombo_);
    lastProfileId_ = profileCombo_.getSelectedId();

    profileHelpLabel_.setText("Auto: sliders read-only, values follow auto-tune. WSL 20/10/16 | Local 12/4/8 | LAN 16/8/12 pkt.",
                                juce::dontSendNotification);
    profileHelpLabel_.setFont(juce::FontOptions(11.0f));
    profileHelpLabel_.setColour(juce::Label::textColourId, juce::Colours::grey);
    addAndMakeVisible(profileHelpLabel_);

    autoTuneButton_.setToggleState(bridge.getAutoTune(), juce::dontSendNotification);
    addAndMakeVisible(autoTuneButton_);

    autoTuneHelpLabel_.setText("Raises reserve on underrun/Bursty; lowers slowly if Smooth 30+ s.",
                               juce::dontSendNotification);
    autoTuneHelpLabel_.setFont(juce::FontOptions(11.0f));
    autoTuneHelpLabel_.setColour(juce::Label::textColourId, juce::Colours::grey);
    addAndMakeVisible(autoTuneHelpLabel_);

    testNoteButton_.setToggleMode(true);
    testNoteButton_.setTooltip("Toggle test note C4 (Play + connected only)");
    testNoteButton_.onClick = [this]() {
        applySettings();
        processor_.setTestNote(!processor_.isTestNoteOn());
        updateTransportControls();
    };
    addAndMakeVisible(testNoteButton_);

    playButton_.setToggleMode(false);
    playButton_.onClick = [this]() {
        applySettings();
        resumePlayWhenConnected_ = false;
        processor_.startPlayback();
        lastConnected_ = processor_.getNetBridge().isConnected();
    };
    addAndMakeVisible(playButton_);

    stopButton_.setToggleMode(false);
    stopButton_.onClick = [this]() {
        resumePlayWhenConnected_ = false;
        processor_.stopAllNotes();
    };
    addAndMakeVisible(stopButton_);

    resetStatsLink_.setColour(juce::TextButton::buttonColourId, juce::Colours::transparentBlack);
    resetStatsLink_.setColour(juce::TextButton::buttonOnColourId, juce::Colours::transparentBlack);
    resetStatsLink_.setColour(juce::TextButton::textColourOffId, juce::Colour(0xff6aa8ff));
    resetStatsLink_.setColour(juce::TextButton::textColourOnId, juce::Colour(0xff9ec5ff));
    resetStatsLink_.onClick = [this]() { processor_.resetBridgeStats(); };
    addAndMakeVisible(resetStatsLink_);

    addAndMakeVisible(bufferBar_);

    statusLabel_.setText("Status: starting...", juce::dontSendNotification);
    statusLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(statusLabel_);

    statsLine1Label_.setText("Fill: 0/0 pkt", juce::dontSendNotification);
    statsLine1Label_.setJustificationType(juce::Justification::centredLeft);
    statsLine1Label_.setFont(juce::FontOptions(11.0f));
    addAndMakeVisible(statsLine1Label_);

    statsLine2Label_.setText("Profile: Auto", juce::dontSendNotification);
    statsLine2Label_.setJustificationType(juce::Justification::centredLeft);
    statsLine2Label_.setFont(juce::FontOptions(11.0f));
    statsLine2Label_.setColour(juce::Label::textColourId, juce::Colours::lightgrey);
    addAndMakeVisible(statsLine2Label_);

    lastHost_ = processor_.getNetBridge().getEngineHost();
    updateControlsForProfile();
    syncSlidersFromBridge();
    updateTransportControls();

    startTimerHz(4);
}

HdlVerilatorAudioProcessorEditor::~HdlVerilatorAudioProcessorEditor() = default;

juce::String HdlVerilatorAudioProcessorEditor::deliveryQualityLabel(DeliveryQuality q) {
    switch (q) {
    case DeliveryQuality::Smooth:
        return "Smooth";
    case DeliveryQuality::Moderate:
        return "Moderate";
    case DeliveryQuality::Bursty:
        return "Bursty";
    default:
        return "Unknown";
    }
}

void HdlVerilatorAudioProcessorEditor::paint(juce::Graphics& g) {
    g.fillAll(getLookAndFeel().findColour(juce::ResizableWindow::backgroundColourId));
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
    synthEditor_->setBounds(area.removeFromTop(kSynthPanelHeight));
    area.removeFromTop(8);

    auto header = area.removeFromTop(28);
    titleLabel_.setBounds(header.removeFromLeft(header.getWidth() * 2 / 5));
    versionLabel_.setBounds(header);

    area.removeFromTop(6);
    hostLabel_.setBounds(area.removeFromTop(18));
    area.removeFromTop(4);

    auto hostRow = area.removeFromTop(28);
    connectionIndicator_.setBounds(hostRow.removeFromLeft(14));
    hostRow.removeFromLeft(4);
    reconnectButton_.setBounds(hostRow.removeFromRight(88));
    hostRow.removeFromRight(8);
    hostEditor_.setBounds(hostRow);

    auto sliderRow = [&](juce::Label& label, juce::Slider& slider) {
        area.removeFromTop(6);
        label.setBounds(area.removeFromTop(18));
        area.removeFromTop(2);
        slider.setBounds(area.removeFromTop(26));
    };

    sliderRow(minReserveLabel_, minReserveSlider_);
    sliderRow(targetReserveLabel_, targetReserveSlider_);
    sliderRow(warmupLabel_, warmupSlider_);

    area.removeFromTop(6);
    profileLabel_.setBounds(area.removeFromTop(18));
    area.removeFromTop(4);
    profileCombo_.setBounds(area.removeFromTop(26));
    area.removeFromTop(2);
    profileHelpLabel_.setBounds(area.removeFromTop(24));

    area.removeFromTop(6);
    autoTuneButton_.setBounds(area.removeFromTop(26));
    area.removeFromTop(2);
    autoTuneHelpLabel_.setBounds(area.removeFromTop(20));

    area.removeFromTop(6);
    auto transport = area.removeFromTop(30);
    const int gap = 8;
    const int buttonWidth = (transport.getWidth() - gap * 2) / 3;
    testNoteButton_.setBounds(transport.removeFromLeft(buttonWidth));
    transport.removeFromLeft(gap);
    playButton_.setBounds(transport.removeFromLeft(buttonWidth));
    transport.removeFromLeft(gap);
    stopButton_.setBounds(transport.removeFromLeft(buttonWidth));

    area.removeFromTop(8);
    bufferBar_.setBounds(area.removeFromTop(18));

    area.removeFromTop(8);
    statusLabel_.setBounds(area.removeFromTop(20));
    area.removeFromTop(2);
    statsLine1Label_.setBounds(area.removeFromTop(16));
    area.removeFromTop(2);
    auto statsRow2 = area.removeFromTop(16);
    resetStatsLink_.setBounds(statsRow2.removeFromRight(72));
    statsRow2.removeFromRight(6);
    statsLine2Label_.setBounds(statsRow2);
}

void HdlVerilatorAudioProcessorEditor::updateControlsForProfile() {
    const bool autoProfile =
        processor_.getNetBridge().getNetworkProfile() == NetworkProfile::Auto;
    juce::Slider* sliders[] = {&minReserveSlider_, &targetReserveSlider_, &warmupSlider_};
    for (auto* slider : sliders) {
        slider->setEnabled(!autoProfile);
        slider->setAlpha(autoProfile ? 0.55f : 1.0f);
    }
}

void HdlVerilatorAudioProcessorEditor::syncSlidersFromBridge() {
    const auto& bridge = processor_.getNetBridge();
    const int minPkt = bridge.getMinReservePackets();
    const int targetPkt = bridge.getTargetReservePackets();
    const int warmupPkt = bridge.getInitialWarmupPackets();

    if (minPkt != lastSyncedMin_) {
        minReserveSlider_.setValue(minPkt, juce::dontSendNotification);
        lastSyncedMin_ = minPkt;
    }
    if (targetPkt != lastSyncedTarget_) {
        targetReserveSlider_.setValue(targetPkt, juce::dontSendNotification);
        lastSyncedTarget_ = targetPkt;
    }
    if (warmupPkt != lastSyncedWarmup_) {
        warmupSlider_.setValue(warmupPkt, juce::dontSendNotification);
        lastSyncedWarmup_ = warmupPkt;
    }
}

void HdlVerilatorAudioProcessorEditor::applySettings() {
    const auto host = hostEditor_.getText().trim();
    auto& bridge = processor_.getNetBridge();

    const int profileId = profileCombo_.getSelectedId();
    if (profileId != lastProfileId_) {
        lastProfileId_ = profileId;
        bridge.setNetworkProfile(static_cast<NetworkProfile>(profileId - 1));
        lastSyncedMin_ = lastSyncedTarget_ = lastSyncedWarmup_ = -1;
        syncSlidersFromBridge();
        updateControlsForProfile();
        if (processor_.isTestNoteOn()) {
            processor_.reassertTestNote();
        }
    }

    if (host != lastHost_) {
        lastHost_ = host;
        processor_.setEngineHost(host);
        if (bridge.getNetworkProfile() == NetworkProfile::Auto) {
            bridge.resetReservesToProfile();
            lastSyncedMin_ = lastSyncedTarget_ = lastSyncedWarmup_ = -1;
            syncSlidersFromBridge();
        }
        if (processor_.isTestNoteOn()) {
            processor_.reassertTestNote();
        }
    }

    bridge.setAutoTune(autoTuneButton_.getToggleState());

    if (bridge.getNetworkProfile() == NetworkProfile::Auto) {
        return;
    }

    bridge.setMinReservePackets(static_cast<int>(minReserveSlider_.getValue()));
    bridge.setTargetReservePackets(static_cast<int>(targetReserveSlider_.getValue()));
    bridge.setInitialWarmupPackets(static_cast<int>(warmupSlider_.getValue()));
}

void HdlVerilatorAudioProcessorEditor::updateStatusText() {
    const auto& bridge = processor_.getNetBridge();
    juce::String status;
    if (bridge.isMuted()) {
        status = "Status: MUTED - click Play (Stop silences output)";
    } else if (bridge.isPrimed() && bridge.getBufferedSamples() > 0) {
        status = "Status: streaming PCM (pull mode)";
    } else if (bridge.isConnected()) {
        status = "Status: connected, warming up buffer";
    } else if (bridge.getBufferedSamples() > 0) {
        status = "Status: receiving PCM (no ACK yet)";
    } else {
        status = "Status: waiting for engine - check IP, WSL, firewall";
    }

    if (bridge.getDeliveryQuality() == DeliveryQuality::Bursty &&
        processor_.getNetBridge().getEngineHost().startsWith("172.")) {
        status += " | WSL bursty: try mirrored networking or native engine";
    }
    statusLabel_.setText(status, juce::dontSendNotification);
}

void HdlVerilatorAudioProcessorEditor::updateTransportControls() {
    const auto& bridge = processor_.getNetBridge();
    const bool connected = bridge.isConnected();
    const bool playing = connected && !bridge.isMuted();
    const bool stopped = connected && bridge.isMuted();
    const bool canTestNote = connected && playing;

    playButton_.setEnabled(connected);
    playButton_.setLampColour(playing ? LampColour::Green : LampColour::Off);

    stopButton_.setEnabled(connected);
    stopButton_.setLampColour(stopped ? LampColour::Red : LampColour::Off);

    testNoteButton_.setToggled(processor_.isTestNoteOn());
    testNoteButton_.setLampColour(processor_.isTestNoteOn() ? LampColour::Green : LampColour::Off);
    testNoteButton_.setEnabled(canTestNote);
}

void HdlVerilatorAudioProcessorEditor::timerCallback() {
    applySettings();
    updateStatusText();

    connectionIndicator_.setIndicatorColour(linkColour());

    const auto& bridge = processor_.getNetBridge();
    const int fillPackets = bridge.getBufferedSamples() / hdlnet::kMaxAudioFrames;
    const int targetPackets = bridge.getTargetBufferSamples() / hdlnet::kMaxAudioFrames;
    const int effectiveMin = bridge.getEffectiveMinReservePackets();

    if (bridge.getNetworkProfile() == NetworkProfile::Auto) {
        syncSlidersFromBridge();
    }

    bufferBar_.setLevels(fillPackets, targetPackets, effectiveMin, bridge.getEstimatedLatencyMs());

    juce::String profileText = networkProfileLabel(bridge.getNetworkProfile());
    if (bridge.getNetworkProfile() == NetworkProfile::Auto) {
        profileText += " -> " + juce::String(networkProfileLabel(bridge.getActiveProfile()));
    }

    statsLine1Label_.setText("Fill: " + juce::String(fillPackets) + "/" + juce::String(targetPackets) +
                                 " pkt | eff.min " + juce::String(effectiveMin) + " | Latency ~" +
                                 juce::String(bridge.getEstimatedLatencyMs(), 0) + " ms",
                             juce::dontSendNotification);

    statsLine2Label_.setText("Profile: " + profileText + " | " +
                                 deliveryQualityLabel(bridge.getDeliveryQuality()) + " | p95 " +
                                 juce::String(bridge.getP95JitterMs(), 1) + " ms | Underruns " +
                                 juce::String(bridge.getUnderruns()) + " | Pulls " +
                                 juce::String(bridge.getPullCount()) + (bridge.isMuted() ? " | muted" : ""),
                             juce::dontSendNotification);

    updateTransportControls();

    const bool connected = bridge.isConnected();
    if (!connected && lastConnected_) {
        if (!processor_.takeSuppressDisconnectStop()) {
            if (processor_.isTestNoteOn()) {
                processor_.setTestNote(false);
            }
            processor_.setBridgeMuted(true);
            resumePlayWhenConnected_ = true;
        }
    }
    if (connected && resumePlayWhenConnected_ && bridge.isMuted()) {
        resumePlayWhenConnected_ = false;
        processor_.resumePlaybackOnConnect();
    }
    lastConnected_ = connected;

    repaint();
}
