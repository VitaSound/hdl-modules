#pragma once

#include <atomic>
#include <cstdint>
#include <vector>

#include <JuceHeader.h>
#include "DeliveryQualityMonitor.h"
#include "hdl_net.h"

struct PendingMidiEvent {
    hdlnet::PacketType type = hdlnet::PacketType::NoteOn;
    uint8_t note = 0;
    uint8_t velocity = 0;
    uint8_t cc = 0;
    uint8_t value = 0;
    uint16_t pitch = 8192;
    uint64_t timestampUs = 0;
};

class NetBridge : private juce::Thread {
public:
    NetBridge();
    ~NetBridge() override;

    void prepare(double sampleRate, int blockSize);
    void shutdown();

    void setEngineHost(const juce::String& host);
    juce::String getEngineHost() const;

    void setControlPort(uint16_t port);
    void setAudioPort(uint16_t port);

    void setMinReservePackets(int packets);
    void setTargetReservePackets(int packets);
    void setInitialWarmupPackets(int packets);
    void setMaxPacketsPerPull(int packets);
    void setAutoTune(bool on);
    void setNetworkProfile(NetworkProfile profile);
    void resetReservesToProfile();

    int getMinReservePackets() const { return minReservePackets_; }
    int getTargetReservePackets() const { return targetReservePackets_; }
    int getInitialWarmupPackets() const { return initialWarmupPackets_; }
    int getMaxPacketsPerPull() const { return maxPacketsPerPull_; }
    bool getAutoTune() const { return autoTune_; }
    NetworkProfile getNetworkProfile() const { return networkProfile_; }

    void queueMidi(const PendingMidiEvent& event);
    void readAudio(float* left, float* right, int numSamples);

    bool isConnected() const { return connected_.load(); }
    bool isPrimed() const { return primed_; }
    bool isMuted() const { return muted_.load(); }
    int getUnderruns() const { return underruns_.load(); }
    int getPullCount() const { return pulls_.load(); }
    int getBufferedSamples() const;
    int getTargetBufferSamples() const;
    int getWarmupBufferSamples() const;
    double getEstimatedLatencyMs() const;
    DeliveryQuality getDeliveryQuality() const;
    double getP95JitterMs() const;
    int getEffectiveMinReservePackets() const;
    NetworkProfile getActiveProfile() const;

    void reconnect();
    void resetStats();
    void setMuted(bool muted);
    void sendAllNotesOff();

private:
    void run() override;
    void sendHello(juce::DatagramSocket& socket);
    void sendPull(juce::DatagramSocket& socket, uint32_t frameCount);
    void maybeRequestAudio(juce::DatagramSocket& socket);
    void runAutoTune(uint64_t nowUs);
    void applyProfileDefaults();
    void handleControlPacket(const uint8_t* data, int size);
    void pushAudioSamples(const int16_t* interleaved, int frames, int channels);
    void noteActivity(uint64_t nowUs);
    void checkConnectionTimeout(uint64_t nowUs);
    void markDisconnected();

    int minReserveSamples() const { return minReservePackets_ * kPacketFrames; }
    int targetFillSamples() const { return targetReservePackets_ * kPacketFrames; }
    int warmupFillSamples() const { return initialWarmupPackets_ * kPacketFrames; }
    int effectiveMinReservePackets() const;

    static constexpr int kPacketFrames = hdlnet::kMaxAudioFrames;
    static constexpr int kMaxReservePackets = 24;

    juce::String engineHost_{"127.0.0.1"};
    uint16_t controlPort_ = hdlnet::kDefaultControlPort;
    uint16_t audioPort_ = hdlnet::kDefaultAudioPort;

    int minReservePackets_ = 10;
    int targetReservePackets_ = 16;
    int initialWarmupPackets_ = 20;
    int maxPacketsPerPull_ = 8;
    bool autoTune_ = true;
    NetworkProfile networkProfile_ = NetworkProfile::Auto;

    double sampleRate_ = 48000.0;
    int blockSize_ = 512;

    std::atomic<bool> connected_{false};
    std::atomic<bool> running_{false};
    std::atomic<bool> muted_{true};
    std::atomic<int> underruns_{0};
    std::atomic<int> pulls_{0};
    std::atomic<uint32_t> seq_{0};
    std::atomic<uint32_t> pullRequestId_{0};

    juce::WaitableEvent settingsChanged_;

    static constexpr int kMaxMidiQueue = 4096;
    juce::AbstractFifo midiFifo_{kMaxMidiQueue};
    std::vector<PendingMidiEvent> midiBuffer_;

    static constexpr int kMaxAudioSamples = 48000 * 8;
    juce::AbstractFifo audioFifo_{kMaxAudioSamples};
    std::vector<float> audioLeft_;
    std::vector<float> audioRight_;

    float lastLeft_ = 0.0f;
    float lastRight_ = 0.0f;
    bool primed_ = false;
    bool pullInFlight_ = false;
    uint64_t lastPullUs_ = 0;
    uint64_t lastAutoTuneUs_ = 0;
    uint64_t lastDecreaseUs_ = 0;
    uint64_t connectTimeUs_ = 0;
    uint64_t lastActivityUs_ = 0;
    uint64_t lastHelloUs_ = 0;
    int underrunsAtLastTune_ = 0;

    static constexpr uint64_t kActivityTimeoutUs = 3'000'000;
    static constexpr uint64_t kHelloIntervalUs = 500'000;

    DeliveryQualityMonitor deliveryMonitor_;

    juce::CriticalSection settingsLock_;
};
