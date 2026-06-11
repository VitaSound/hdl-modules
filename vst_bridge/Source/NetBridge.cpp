#include "NetBridge.h"

namespace {
uint64_t nowUs() {
    return static_cast<uint64_t>(juce::Time::getHighResolutionTicks() *
                                 (1'000'000.0 / juce::Time::getHighResolutionTicksPerSecond()));
}
} // namespace

NetBridge::NetBridge() : juce::Thread("HdlNetBridge") {
    midiBuffer_.resize(static_cast<size_t>(kMaxMidiQueue));
    audioLeft_.resize(static_cast<size_t>(kMaxAudioSamples));
    audioRight_.resize(static_cast<size_t>(kMaxAudioSamples));
}

NetBridge::~NetBridge() {
    shutdown();
}

int NetBridge::warmupBufferSamples() const {
    // Start playback after one DAW block; jitter slider caps max latency, not startup silence.
    return blockSize_;
}

int NetBridge::targetBufferSamples() const {
    return juce::jmax(warmupBufferSamples(),
                      static_cast<int>(sampleRate_ * jitterMs_ / 1000.0));
}

int NetBridge::getTargetBufferSamples() const {
    return targetBufferSamples();
}

int NetBridge::getWarmupBufferSamples() const {
    return warmupBufferSamples();
}

void NetBridge::prepare(double sampleRate, int blockSize, int jitterMs) {
    const bool sameRuntime = isThreadRunning() && running_.load() && sampleRate_ == sampleRate &&
                             blockSize_ == blockSize && jitterMs_ == jitterMs;
    sampleRate_ = sampleRate;
    blockSize_ = blockSize;
    jitterMs_ = jitterMs;

    if (sameRuntime) {
        return;
    }

    shutdown();
    midiFifo_.reset();
    audioFifo_.reset();
    underruns_.store(0);
    connected_.store(false);
    primed_ = false;
    lastLeft_ = 0.0f;
    lastRight_ = 0.0f;
    seq_.store(0);
    running_.store(true);
    startThread();
}

void NetBridge::shutdown() {
    running_.store(false);
    settingsChanged_.signal();
    stopThread(3000);
    connected_.store(false);
    primed_ = false;
}

void NetBridge::setEngineHost(const juce::String& host) {
    juce::ScopedLock lock(settingsLock_);
    if (host == engineHost_) {
        return;
    }
    engineHost_ = host;
    connected_.store(false);
    primed_ = false;
    settingsChanged_.signal();
}

juce::String NetBridge::getEngineHost() const {
    juce::ScopedLock lock(settingsLock_);
    return engineHost_;
}

void NetBridge::setControlPort(uint16_t port) {
    if (port == controlPort_) {
        return;
    }
    controlPort_ = port;
    connected_.store(false);
    primed_ = false;
    settingsChanged_.signal();
}

void NetBridge::setAudioPort(uint16_t port) {
    if (port == audioPort_) {
        return;
    }
    audioPort_ = port;
    connected_.store(false);
    primed_ = false;
    settingsChanged_.signal();
}

void NetBridge::setJitterMs(int ms) {
    ms = juce::jlimit(10, 200, ms);
    if (ms == jitterMs_) {
        return;
    }
    jitterMs_ = ms;
    primed_ = false;
}

void NetBridge::queueMidi(const PendingMidiEvent& event) {
    int start1 = 0;
    int size1 = 0;
    int start2 = 0;
    int size2 = 0;
    midiFifo_.prepareToWrite(1, start1, size1, start2, size2);
    if (size1 <= 0) {
        return;
    }
    midiBuffer_[static_cast<size_t>(start1)] = event;
    midiFifo_.finishedWrite(1);
}

void NetBridge::readAudio(float* left, float* right, int numSamples) {
    const int available = audioFifo_.getNumReady();
    const int warmup = warmupBufferSamples();

    if (!primed_) {
        if (available < warmup) {
            for (int i = 0; i < numSamples; ++i) {
                left[i] = lastLeft_;
                right[i] = lastRight_;
            }
            underruns_.fetch_add(numSamples);
            return;
        }
        primed_ = true;
    }

    const int toRead = juce::jmin(numSamples, available);
    if (toRead < numSamples) {
        underruns_.fetch_add(numSamples - toRead);
    }

    int start1 = 0;
    int size1 = 0;
    int start2 = 0;
    int size2 = 0;
    audioFifo_.prepareToRead(toRead, start1, size1, start2, size2);

    int outIdx = 0;
    for (int i = 0; i < size1; ++i) {
        lastLeft_ = audioLeft_[static_cast<size_t>(start1 + i)];
        lastRight_ = audioRight_[static_cast<size_t>(start1 + i)];
        left[outIdx] = lastLeft_;
        right[outIdx] = lastRight_;
        ++outIdx;
    }
    for (int i = 0; i < size2; ++i) {
        lastLeft_ = audioLeft_[static_cast<size_t>(start2 + i)];
        lastRight_ = audioRight_[static_cast<size_t>(start2 + i)];
        left[outIdx] = lastLeft_;
        right[outIdx] = lastRight_;
        ++outIdx;
    }
    for (int i = toRead; i < numSamples; ++i) {
        left[i] = lastLeft_;
        right[i] = lastRight_;
    }
    audioFifo_.finishedRead(toRead);
}

int NetBridge::getBufferedSamples() const {
    return audioFifo_.getNumReady();
}

void NetBridge::sendHello(juce::DatagramSocket& socket) {
    juce::String host;
    uint16_t ctrlPort = controlPort_;
    {
        juce::ScopedLock lock(settingsLock_);
        host = engineHost_;
    }

    if (host.isEmpty()) {
        return;
    }

    hdlnet::HelloPayload hello{};
    hello.sample_rate = static_cast<uint32_t>(sampleRate_);
    hello.block_size = static_cast<uint16_t>(blockSize_);
    hello.plugin_ssrc = 0x56535431u; // "VST1"
    hello.audio_port = audioPort_;

    std::array<uint8_t, 128> out{};
    const uint32_t seq = seq_.fetch_add(1) + 1;
    const size_t len = hdlnet::encodeHello(out.data(), seq, hello);
    socket.write(host, static_cast<int>(ctrlPort), out.data(), static_cast<int>(len));
}

void NetBridge::handleControlPacket(const uint8_t* data, int size) {
    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    if (!hdlnet::readControlHeader(data, static_cast<size_t>(size), hdr, type)) {
        return;
    }

    if (type == hdlnet::PacketType::Ack || type == hdlnet::PacketType::Pong) {
        connected_.store(true);
    }
}

void NetBridge::trimExcessBuffer() {
    const int maxKeep = targetBufferSamples() + blockSize_;
    while (audioFifo_.getNumReady() > maxKeep) {
        int dropStart1 = 0;
        int dropSize1 = 0;
        int dropStart2 = 0;
        int dropSize2 = 0;
        audioFifo_.prepareToRead(1, dropStart1, dropSize1, dropStart2, dropSize2);
        if (dropSize1 + dropSize2 <= 0) {
            break;
        }
        audioFifo_.finishedRead(1);
    }
}

void NetBridge::pushAudioSamples(const int16_t* interleaved, int frames, int channels) {
    connected_.store(true);
    constexpr float kScale = 1.0f / 32768.0f;

    for (int frame = 0; frame < frames; ++frame) {
        const int16_t l = interleaved[frame * channels];
        const int16_t r = channels > 1 ? interleaved[frame * channels + 1] : l;

        int start1 = 0;
        int size1 = 0;
        int start2 = 0;
        int size2 = 0;
        audioFifo_.prepareToWrite(1, start1, size1, start2, size2);
        if (size1 <= 0) {
            int dropStart1 = 0;
            int dropSize1 = 0;
            int dropStart2 = 0;
            int dropSize2 = 0;
            audioFifo_.prepareToRead(1, dropStart1, dropSize1, dropStart2, dropSize2);
            if (dropSize1 + dropSize2 > 0) {
                audioFifo_.finishedRead(1);
            }
            audioFifo_.prepareToWrite(1, start1, size1, start2, size2);
            if (size1 <= 0) {
                continue;
            }
        }

        audioLeft_[static_cast<size_t>(start1)] = static_cast<float>(l) * kScale;
        audioRight_[static_cast<size_t>(start1)] = static_cast<float>(r) * kScale;
        audioFifo_.finishedWrite(1);
    }
    trimExcessBuffer();
}

void NetBridge::run() {
    juce::DatagramSocket controlSocket;
    juce::DatagramSocket audioSocket;

    if (!audioSocket.bindToPort(static_cast<int>(audioPort_))) {
        juce::Logger::writeToLog("HdlVerilator: failed to bind audio UDP port " +
                                 juce::String(audioPort_));
        running_.store(false);
        return;
    }
    if (!controlSocket.bindToPort(0)) {
        juce::Logger::writeToLog("HdlVerilator: failed to bind control UDP socket");
        running_.store(false);
        return;
    }

    sendHello(controlSocket);

    std::array<uint8_t, hdlnet::kMaxAudioPacketBytes> buffer{};
    int helloCounter = 0;

    while (running_.load() && !threadShouldExit()) {
        if (settingsChanged_.wait(10)) {
            sendHello(controlSocket);
        }

        if (++helloCounter > 200) {
            helloCounter = 0;
            if (!connected_.load()) {
                sendHello(controlSocket);
            }
        }

        while (midiFifo_.getNumReady() > 0) {
            int start1 = 0;
            int size1 = 0;
            int start2 = 0;
            int size2 = 0;
            midiFifo_.prepareToRead(1, start1, size1, start2, size2);
            if (size1 <= 0) {
                break;
            }

            const auto& event = midiBuffer_[static_cast<size_t>(start1)];
            midiFifo_.finishedRead(1);

            juce::String host;
            uint16_t ctrlPort = controlPort_;
            {
                juce::ScopedLock lock(settingsLock_);
                host = engineHost_;
            }

            hdlnet::NotePayload note{};
            note.timestamp_us = event.timestampUs != 0 ? event.timestampUs : nowUs();
            note.note = event.note;
            note.velocity = event.velocity;

            std::array<uint8_t, 64> out{};
            const uint32_t seq = seq_.fetch_add(1) + 1;
            const size_t len = hdlnet::encodeNote(out.data(), event.type, seq, note);
            controlSocket.write(host, static_cast<int>(ctrlPort), out.data(), static_cast<int>(len));
        }

        juce::String sender;
        int senderPort = 0;
        const int ctrlBytes =
            controlSocket.read(buffer.data(), static_cast<int>(buffer.size()), false, sender, senderPort);
        if (ctrlBytes > 0) {
            handleControlPacket(buffer.data(), ctrlBytes);
        }

        const int audioBytes =
            audioSocket.read(buffer.data(), static_cast<int>(buffer.size()), false, sender, senderPort);
        if (audioBytes > 0) {
            hdlnet::AudioHeader hdr{};
            size_t payloadBytes = 0;
            if (hdlnet::decodeAudioHeader(buffer.data(), static_cast<size_t>(audioBytes), hdr, payloadBytes)) {
                const auto* samples =
                    reinterpret_cast<const int16_t*>(buffer.data() + sizeof(hdlnet::AudioHeader));
                pushAudioSamples(samples, hdr.frame_count, hdr.channels);
            }
        }
    }
}
