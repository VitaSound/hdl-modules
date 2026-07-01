#pragma once

#include <JuceHeader.h>
#include "BufferLevelBar.h"
#include "ConnectionIndicator.h"
#include "PanelLampButton.h"
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
    void updateControlsForProfile();
    void syncSlidersFromBridge();
    void updateTransportControls();
    juce::Colour linkColour() const;
    static juce::String deliveryQualityLabel(DeliveryQuality q);

    HdlVerilatorAudioProcessor& processor_;

    juce::Label titleLabel_;
    juce::Label versionLabel_;
    juce::Label hostLabel_;
    ConnectionIndicator connectionIndicator_;
    juce::TextEditor hostEditor_;
    juce::TextButton reconnectButton_{"Reconnect"};
    juce::Label minReserveLabel_;
    juce::Slider minReserveSlider_;
    juce::Label targetReserveLabel_;
    juce::Slider targetReserveSlider_;
    juce::Label warmupLabel_;
    juce::Slider warmupSlider_;
    juce::Label profileLabel_;
    juce::ComboBox profileCombo_;
    juce::Label profileHelpLabel_;
    juce::ToggleButton autoTuneButton_{"Auto-tune buffers"};
    juce::Label autoTuneHelpLabel_;
    PanelLampButton testNoteButton_{"Test note"};
    PanelLampButton playButton_{"Play"};
    PanelLampButton stopButton_{"Stop"};
    BufferLevelBar bufferBar_;
    juce::Label statusLabel_;
    juce::Label statsLine1Label_;
    juce::Label statsLine2Label_;
    juce::TextButton resetStatsLink_{"Reset stats"};
    std::unique_ptr<juce::GenericAudioProcessorEditor> synthEditor_;

    juce::String lastHost_;
    int lastProfileId_ = -1;
    int lastSyncedMin_ = -1;
    int lastSyncedTarget_ = -1;
    int lastSyncedWarmup_ = -1;
    bool lastConnected_ = false;
    bool resumePlayWhenConnected_ = true;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HdlVerilatorAudioProcessorEditor)
};
