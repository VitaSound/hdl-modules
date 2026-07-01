#pragma once

#include <memory>

#include <JuceHeader.h>
#include "NetBridge.h"
#include "SynthParamSchema.h"

class HdlVerilatorAudioProcessor : public juce::AudioProcessor,
                                   private juce::AudioProcessorValueTreeState::Listener {
public:
    HdlVerilatorAudioProcessor();
    ~HdlVerilatorAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    bool isBusesLayoutSupported(const BusesLayout& layouts) const override;

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
    void startPlayback();
    void resumePlaybackOnConnect();
    void resetBridgeStats();
    bool takeSuppressDisconnectStop();
    void setBridgeMuted(bool muted);
    void stopAllNotes();
    void setTestNote(bool on);
    void reassertTestNote();
    bool isTestNoteOn() const { return testNoteOn_; }

    NetBridge& getNetBridge() { return netBridge_; }
    juce::AudioProcessorValueTreeState& getApvts() { return apvts_; }
    juce::String getParamSchemaStatus() const { return schema_.source; }
    uint32_t getParamSchemaHash() const { return schema_.hash; }

private:
    void fullReconnect(bool enterStopMode);
    void parameterChanged(const juce::String& parameterID, float newValue) override;
    void sendAllApvtsAsMidi();

    NetBridge netBridge_;
    SynthParamSchema schema_;
    juce::AudioProcessorValueTreeState apvts_;
    juce::String engineHost_{"127.0.0.1"};
    uint16_t controlPort_ = hdlnet::kDefaultControlPort;
    uint16_t audioPort_ = hdlnet::kDefaultAudioPort;
    bool testNoteOn_ = false;
    bool suppressDisconnectStop_ = false;
    bool suppressParamMidi_ = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HdlVerilatorAudioProcessor)
};
