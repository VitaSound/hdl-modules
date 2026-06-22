#include "PluginProcessor.h"
#include "PluginEditor.h"

HdlVerilatorAudioProcessor::HdlVerilatorAudioProcessor()
    : juce::AudioProcessor(
          BusesProperties().withOutput("Output", juce::AudioChannelSet::stereo(), true)) {}

HdlVerilatorAudioProcessor::~HdlVerilatorAudioProcessor() = default;

void HdlVerilatorAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock) {
    if (netBridge_.getEngineHost().isNotEmpty()) {
        engineHost_ = netBridge_.getEngineHost();
    } else if (engineHost_.isNotEmpty()) {
        netBridge_.setEngineHost(engineHost_);
    }
    netBridge_.setControlPort(controlPort_);
    netBridge_.setAudioPort(audioPort_);
    netBridge_.prepare(sampleRate, samplesPerBlock);
}

void HdlVerilatorAudioProcessor::setEngineHost(const juce::String& host) {
    engineHost_ = host;
    netBridge_.setEngineHost(host);
}

void HdlVerilatorAudioProcessor::fullReconnect(bool enterStopMode) {
    if (testNoteOn_) {
        setTestNote(false);
    }
    resetBridgeStats();
    netBridge_.reconnect();
    setBridgeMuted(enterStopMode);
}

void HdlVerilatorAudioProcessor::reconnectEngine() {
    fullReconnect(true);
}

void HdlVerilatorAudioProcessor::startPlayback() {
    suppressDisconnectStop_ = true;
    fullReconnect(true);
    setBridgeMuted(false);
}

void HdlVerilatorAudioProcessor::resumePlaybackOnConnect() {
    setBridgeMuted(false);
}

bool HdlVerilatorAudioProcessor::takeSuppressDisconnectStop() {
    const bool v = suppressDisconnectStop_;
    suppressDisconnectStop_ = false;
    return v;
}

void HdlVerilatorAudioProcessor::resetBridgeStats() {
    netBridge_.resetStats();
}

void HdlVerilatorAudioProcessor::setBridgeMuted(bool muted) {
    netBridge_.setMuted(muted);
}

void HdlVerilatorAudioProcessor::stopAllNotes() {
    testNoteOn_ = false;
    netBridge_.sendAllNotesOff();
    netBridge_.setMuted(true);
}

void HdlVerilatorAudioProcessor::setTestNote(bool on) {
    if (on == testNoteOn_) {
        return;
    }
    testNoteOn_ = on;

    PendingMidiEvent event{};
    event.bytes = {0x90, 60, static_cast<uint8_t>(on ? 100 : 0)};
    netBridge_.queueMidi(event);
}

void HdlVerilatorAudioProcessor::reassertTestNote() {
    if (!testNoteOn_) {
        return;
    }
    PendingMidiEvent event{};
    event.bytes = {0x90, 60, 100};
    netBridge_.queueMidi(event);
}

void HdlVerilatorAudioProcessor::releaseResources() {
    netBridge_.shutdown();
}

void HdlVerilatorAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi) {
    juce::ScopedNoDenormals noDenormals;
    buffer.clear();

    for (const auto metadata : midi) {
        const auto msg = metadata.getMessage();
        const auto* raw = msg.getRawData();
        const int rawSize = msg.getRawDataSize();
        if (rawSize <= 0 || raw == nullptr) {
            continue;
        }
        PendingMidiEvent event{};
        event.timestampUs = static_cast<uint64_t>(metadata.samplePosition);
        event.bytes.assign(raw, raw + rawSize);
        netBridge_.queueMidi(event);
    }

    auto* left = buffer.getWritePointer(0);
    auto* right = buffer.getNumChannels() > 1 ? buffer.getWritePointer(1) : left;
    netBridge_.readAudio(left, right, buffer.getNumSamples());
}

juce::AudioProcessorEditor* HdlVerilatorAudioProcessor::createEditor() {
    return new HdlVerilatorAudioProcessorEditor(*this);
}

void HdlVerilatorAudioProcessor::getStateInformation(juce::MemoryBlock& destData) {
    juce::ValueTree state("HdlVerilator");
    state.setProperty("engineHost", netBridge_.getEngineHost(), nullptr);
    state.setProperty("controlPort", static_cast<int>(controlPort_), nullptr);
    state.setProperty("audioPort", static_cast<int>(audioPort_), nullptr);
    state.setProperty("minReservePackets", netBridge_.getMinReservePackets(), nullptr);
    state.setProperty("targetReservePackets", netBridge_.getTargetReservePackets(), nullptr);
    state.setProperty("initialWarmupPackets", netBridge_.getInitialWarmupPackets(), nullptr);
    state.setProperty("autoTune", netBridge_.getAutoTune(), nullptr);
    state.setProperty("networkProfile", static_cast<int>(netBridge_.getNetworkProfile()), nullptr);

    if (auto xml = state.createXml()) {
        copyXmlToBinary(*xml, destData);
    }
}

void HdlVerilatorAudioProcessor::setStateInformation(const void* data, int sizeInBytes) {
    if (auto xml = getXmlFromBinary(data, sizeInBytes)) {
        const juce::ValueTree state = juce::ValueTree::fromXml(*xml);
        engineHost_ = state.getProperty("engineHost", engineHost_).toString();
        controlPort_ = static_cast<uint16_t>(static_cast<int>(state.getProperty("controlPort", static_cast<int>(controlPort_))));
        audioPort_ = static_cast<uint16_t>(static_cast<int>(state.getProperty("audioPort", static_cast<int>(audioPort_))));
        netBridge_.setEngineHost(engineHost_);
        netBridge_.setMinReservePackets(static_cast<int>(state.getProperty("minReservePackets", netBridge_.getMinReservePackets())));
        netBridge_.setTargetReservePackets(static_cast<int>(state.getProperty("targetReservePackets", netBridge_.getTargetReservePackets())));
        netBridge_.setInitialWarmupPackets(static_cast<int>(state.getProperty("initialWarmupPackets", netBridge_.getInitialWarmupPackets())));
        netBridge_.setAutoTune(static_cast<bool>(state.getProperty("autoTune", netBridge_.getAutoTune())));
        netBridge_.setNetworkProfile(static_cast<NetworkProfile>(static_cast<int>(state.getProperty("networkProfile", static_cast<int>(netBridge_.getNetworkProfile())))));
    }
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() {
    return new HdlVerilatorAudioProcessor();
}
