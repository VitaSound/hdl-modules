#pragma once

#include <memory>

#include <JuceHeader.h>
#include "NetBridge.h"

class HdlVerilatorAudioProcessor : public juce::AudioProcessor {
public:
    HdlVerilatorAudioProcessor();
    ~HdlVerilatorAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String&) override {}

    void getStateInformation(juce::MemoryBlock& destData) override;
    void setStateInformation(const void* data, int sizeInBytes) override;

    void setEngineHost(const juce::String& host);
    void reconnectEngine();
    void resetBridgeStats();
    void setBridgeMuted(bool muted);
    void stopAllNotes();
    void setTestNote(bool on);
    bool isTestNoteOn() const { return testNoteOn_; }

    int getJitterMs() const { return jitterMs_; }

    NetBridge& getNetBridge() { return netBridge_; }

private:
    NetBridge netBridge_;
    juce::String engineHost_{"127.0.0.1"};
    uint16_t controlPort_ = hdlnet::kDefaultControlPort;
    uint16_t audioPort_ = hdlnet::kDefaultAudioPort;
    int jitterMs_ = 80;
    bool testNoteOn_ = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HdlVerilatorAudioProcessor)
};
