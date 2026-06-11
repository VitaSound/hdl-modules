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
    netBridge_.setJitterMs(jitterMs_);
    netBridge_.prepare(sampleRate, samplesPerBlock, jitterMs_);
}

void HdlVerilatorAudioProcessor::setEngineHost(const juce::String& host) {
    engineHost_ = host;
    netBridge_.setEngineHost(host);
}

void HdlVerilatorAudioProcessor::reconnectEngine() {
    netBridge_.reconnect();
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
    event.note = 60;
    event.velocity = on ? 100 : 0;
    event.type = on ? hdlnet::PacketType::NoteOn : hdlnet::PacketType::NoteOff;
    netBridge_.queueMidi(event);

    if (on) {
        netBridge_.setMuted(false);
    }
}

void HdlVerilatorAudioProcessor::releaseResources() {
    netBridge_.shutdown();
}

void HdlVerilatorAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi) {
    juce::ScopedNoDenormals noDenormals;
    buffer.clear();

    for (const auto metadata : midi) {
        const auto msg = metadata.getMessage();
        PendingMidiEvent event{};
        event.timestampUs = static_cast<uint64_t>(metadata.samplePosition);

        if (msg.isNoteOn()) {
            event.type = hdlnet::PacketType::NoteOn;
            event.note = static_cast<uint8_t>(msg.getNoteNumber());
            event.velocity = static_cast<uint8_t>(msg.getVelocity());
            netBridge_.queueMidi(event);
        } else if (msg.isNoteOff()) {
            event.type = hdlnet::PacketType::NoteOff;
            event.note = static_cast<uint8_t>(msg.getNoteNumber());
            event.velocity = static_cast<uint8_t>(msg.getVelocity());
            netBridge_.queueMidi(event);
        } else if (msg.isAllNotesOff() || msg.isAllSoundOff()) {
            event.type = hdlnet::PacketType::AllNotesOff;
            netBridge_.queueMidi(event);
        }
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
    state.setProperty("jitterMs", jitterMs_, nullptr);

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
        jitterMs_ = static_cast<int>(state.getProperty("jitterMs", jitterMs_));
        netBridge_.setEngineHost(engineHost_);
        netBridge_.setJitterMs(jitterMs_);
    }
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() {
    return new HdlVerilatorAudioProcessor();
}
