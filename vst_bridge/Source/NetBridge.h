#pragma once

#include <atomic>
#include <cstdint>
#include <vector>

#include <JuceHeader.h>
#include "hdl_net.h"

struct PendingMidiEvent {
    hdlnet::PacketType type = hdlnet::PacketType::NoteOn;
    uint8_t note = 0;
    uint8_t velocity = 0;
    uint64_t timestampUs = 0;
};

class NetBridge : private juce::Thread {
public:
    NetBridge();
    ~NetBridge() override;

    void prepare(double sampleRate, int blockSize, int jitterMs);
    void shutdown();

    void setEngineHost(const juce::String& host);
    juce::String getEngineHost() const;

    void setControlPort(uint16_t port);
    void setAudioPort(uint16_t port);
    void setJitterMs(int ms);

    void queueMidi(const PendingMidiEvent& event);
    void readAudio(float* left, float* right, int numSamples);

    bool isConnected() const { return connected_.load(); }
    int getUnderruns() const { return underruns_.load(); }
    int getBufferedSamples() const;
    int getTargetBufferSamples() const;
    int getWarmupBufferSamples() const;

private:
    void run() override;
    void sendHello(juce::DatagramSocket& socket);
    void handleControlPacket(const uint8_t* data, int size);
    void pushAudioSamples(const int16_t* interleaved, int frames, int channels);
    void trimExcessBuffer();
    int targetBufferSamples() const;
    int warmupBufferSamples() const;

    juce::String engineHost_{"127.0.0.1"};
    uint16_t controlPort_ = hdlnet::kDefaultControlPort;
    uint16_t audioPort_ = hdlnet::kDefaultAudioPort;
    int jitterMs_ = 40;

    double sampleRate_ = 48000.0;
    int blockSize_ = 512;

    std::atomic<bool> connected_{false};
    std::atomic<bool> running_{false};
    std::atomic<int> underruns_{0};
    std::atomic<uint32_t> seq_{0};

    juce::WaitableEvent settingsChanged_;

    static constexpr int kMaxMidiQueue = 4096;
    juce::AbstractFifo midiFifo_{kMaxMidiQueue};
    std::vector<PendingMidiEvent> midiBuffer_;

    static constexpr int kMaxAudioSamples = 48000 * 2;
    juce::AbstractFifo audioFifo_{kMaxAudioSamples};
    std::vector<float> audioLeft_;
    std::vector<float> audioRight_;

    float lastLeft_ = 0.0f;
    float lastRight_ = 0.0f;
    bool primed_ = false;

    juce::CriticalSection settingsLock_;
};
