#include "NetBridge.h"

namespace {
uint64_t nowUs() {
    return static_cast<uint64_t>(juce::Time::getHighResolutionTicks() *
                                 (1'000'000.0 / juce::Time::getHighResolutionTicksPerSecond()));
}

uint32_t roundUpFrames(uint32_t frames, uint32_t packetFrames) {
    if (packetFrames == 0) {
        return frames;
    }
    return ((frames + packetFrames - 1) / packetFrames) * packetFrames;
}
} // namespace

NetBridge::NetBridge() : juce::Thread("HdlNetBridge") {
    midiBuffer_.resize(static_cast<size_t>(kMaxMidiQueue));
    audioLeft_.resize(static_cast<size_t>(kMaxAudioSamples));
    audioRight_.resize(static_cast<size_t>(kMaxAudioSamples));
    pushLeft_.resize(static_cast<size_t>(kMaxPushQueue));
    pushRight_.resize(static_cast<size_t>(kMaxPushQueue));
    applyProfileDefaults();
}

NetBridge::~NetBridge() {
    shutdown();
}

void NetBridge::applyProfileDefaults() {
    NetworkProfile profile = networkProfile_;
    if (profile == NetworkProfile::Auto) {
        profile = inferNetworkProfile(getEngineHost().toStdString());
    }
    ::applyProfileDefaults(profile, initialWarmupPackets_, minReservePackets_, targetReservePackets_);
    targetReservePackets_ = juce::jmax(targetReservePackets_, minReservePackets_ + 2);
    initialWarmupPackets_ = juce::jmax(initialWarmupPackets_, targetReservePackets_);
}

int NetBridge::getEffectiveMinReservePackets() const {
    return effectiveMinReservePackets();
}

NetworkProfile NetBridge::getActiveProfile() const {
    if (networkProfile_ != NetworkProfile::Auto) {
        return networkProfile_;
    }
    return inferNetworkProfile(getEngineHost().toStdString());
}

int NetBridge::effectiveMinReservePackets() const {
    int minPkt = minReservePackets_;
    if (deliveryMonitor_.getQuality() == DeliveryQuality::Bursty) {
        minPkt += 2;
    }
    return minPkt;
}

int NetBridge::getTargetBufferSamples() const {
    return targetFillSamples();
}

int NetBridge::getWarmupBufferSamples() const {
    return warmupFillSamples();
}

double NetBridge::getEstimatedLatencyMs() const {
    if (sampleRate_ <= 0.0) {
        return 0.0;
    }
    return static_cast<double>(audioFifo_.getNumReady()) * 1000.0 / sampleRate_;
}

DeliveryQuality NetBridge::getDeliveryQuality() const {
    return deliveryMonitor_.getQuality();
}

double NetBridge::getP95JitterMs() const {
    return deliveryMonitor_.getP95JitterMs();
}

void NetBridge::prepare(double sampleRate, int blockSize) {
    const bool sameRuntime =
        isThreadRunning() && running_.load() && sampleRate_ == sampleRate && blockSize_ == blockSize;
    sampleRate_ = sampleRate;
    blockSize_ = blockSize;

    if (sameRuntime) {
        return;
    }

    shutdown();
    applyProfileDefaults();
    midiFifo_.reset();
    audioFifo_.reset();
    underruns_.store(0);
    pulls_.store(0);
    connected_.store(false);
    engineCaps_.store(0);
    primed_ = false;
    pullInFlight_ = false;
    lastLeft_ = 0.0f;
    lastRight_ = 0.0f;
    seq_.store(0);
    pullRequestId_.store(0);
    deliveryMonitor_.reset();
    connectTimeUs_ = 0;
    lastAutoTuneUs_ = 0;
    lastDecreaseUs_ = 0;
    underrunsAtLastTune_ = 0;
    running_.store(true);
    startThread(juce::Thread::Priority::high);
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
    applyProfileDefaults();
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

void NetBridge::setMinReservePackets(int packets) {
    packets = juce::jlimit(2, kMaxReservePackets, packets);
    if (packets == minReservePackets_) {
        return;
    }
    minReservePackets_ = packets;
    if (targetReservePackets_ < minReservePackets_ + 2) {
        targetReservePackets_ = minReservePackets_ + 2;
    }
    primed_ = false;
}

void NetBridge::setTargetReservePackets(int packets) {
    packets = juce::jlimit(4, kMaxReservePackets, packets);
    if (packets == targetReservePackets_) {
        return;
    }
    targetReservePackets_ = juce::jmax(packets, minReservePackets_ + 2);
    primed_ = false;
}

void NetBridge::setInitialWarmupPackets(int packets) {
    packets = juce::jlimit(4, kMaxReservePackets, packets);
    if (packets == initialWarmupPackets_) {
        return;
    }
    initialWarmupPackets_ = packets;
    primed_ = false;
}

void NetBridge::setMaxPacketsPerPull(int packets) {
    packets = juce::jlimit(1, 16, packets);
    maxPacketsPerPull_ = packets;
}

void NetBridge::setAutoTune(bool on) {
    autoTune_ = on;
}

void NetBridge::setNetworkProfile(NetworkProfile profile) {
    if (profile == networkProfile_) {
        return;
    }
    networkProfile_ = profile;
    applyProfileDefaults();
    primed_ = false;
    settingsChanged_.signal();
}

void NetBridge::resetReservesToProfile() {
    applyProfileDefaults();
    primed_ = false;
    settingsChanged_.signal();
}

void NetBridge::reconnect() {
    audioFifo_.reset();
    midiFifo_.reset();
    markDisconnected();
    lastLeft_ = 0.0f;
    lastRight_ = 0.0f;
    seq_.store(0);
    pullRequestId_.store(0);
    deliveryMonitor_.reset();
    connectTimeUs_ = 0;
    lastHelloUs_ = 0;
    settingsChanged_.signal();
}

void NetBridge::markDisconnected() {
    connected_.store(false);
    primed_ = false;
    pullInFlight_ = false;
    lastActivityUs_ = 0;
}

void NetBridge::noteActivity(uint64_t nowUs) {
    lastActivityUs_ = nowUs;
}

void NetBridge::checkConnectionTimeout(uint64_t nowUs) {
    if (!connected_.load()) {
        return;
    }
    if (lastActivityUs_ == 0) {
        return;
    }
    if (nowUs - lastActivityUs_ > kActivityTimeoutUs) {
        markDisconnected();
        lastHelloUs_ = 0;
    }
}

void NetBridge::resetStats() {
    underruns_.store(0);
    pulls_.store(0);
    underrunsAtLastTune_ = 0;
    deliveryMonitor_.reset();
}

void NetBridge::setMuted(bool muted) {
    muted_.store(muted);
    if (muted) {
        // Freeze auto-tune baseline so a burst of stale underruns is not applied on resume.
        underrunsAtLastTune_ = underruns_.load();
    }
}

void NetBridge::sendAllNotesOff() {
    PendingMidiEvent event{};
    event.bytes = {0xB0, 123, 0};
    queueMidi(event);
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
    if (muted_.load()) {
        juce::FloatVectorOperations::clear(left, numSamples);
        if (right != left) {
            juce::FloatVectorOperations::clear(right, numSamples);
        }
        return;
    }

    const int available = audioFifo_.getNumReady();
    const int warmup = warmupFillSamples();

    if (!primed_) {
        if (available < warmup) {
            juce::FloatVectorOperations::clear(left, numSamples);
            if (right != left) {
                juce::FloatVectorOperations::clear(right, numSamples);
            }
            return;
        }
        primed_ = true;
    }

    const int toRead = juce::jmin(numSamples, available);
    if (toRead <= 0) {
        juce::FloatVectorOperations::clear(left, numSamples);
        if (right != left) {
            juce::FloatVectorOperations::clear(right, numSamples);
        }
        underruns_.fetch_add(numSamples);
        return;
    }

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
    audioFifo_.finishedRead(toRead);

    if (toRead < numSamples) {
        const int missing = numSamples - toRead;
        const int fadeLen = juce::jmin(missing, 64);
        for (int i = 0; i < fadeLen; ++i) {
            const float gain = 1.0f - (static_cast<float>(i + 1) / static_cast<float>(fadeLen));
            left[toRead + i] = lastLeft_ * gain;
            right[toRead + i] = lastRight_ * gain;
        }
        if (missing > fadeLen) {
            juce::FloatVectorOperations::clear(left + toRead + fadeLen, missing - fadeLen);
            if (right != left) {
                juce::FloatVectorOperations::clear(right + toRead + fadeLen, missing - fadeLen);
            }
        }
    }

    const int fillAfter = audioFifo_.getNumReady();
    if (fillAfter < minReserveSamples()) {
        deliveryMonitor_.recordFillBelowMin();
    }
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
    hello.session_mode = hdlnet::kSessionModePull;
    hello.packet_frames = kPacketFrames;
    hello.initial_warmup_packets = static_cast<uint16_t>(initialWarmupPackets_);
    hello.min_reserve_packets = static_cast<uint16_t>(minReservePackets_);
    hello.target_reserve_packets = static_cast<uint16_t>(targetReservePackets_);

    std::array<uint8_t, 128> out{};
    const uint32_t seq = seq_.fetch_add(1) + 1;
    const size_t len = hdlnet::encodeHello(out.data(), seq, hello);
    socket.write(host, static_cast<int>(ctrlPort), out.data(), static_cast<int>(len));
}

void NetBridge::sendPull(juce::DatagramSocket& socket, uint32_t frameCount) {
    juce::String host;
    uint16_t ctrlPort = controlPort_;
    {
        juce::ScopedLock lock(settingsLock_);
        host = engineHost_;
    }
    if (host.isEmpty() || frameCount == 0) {
        return;
    }

    frameCount = roundUpFrames(frameCount, kPacketFrames);
    const uint32_t maxFrames =
        static_cast<uint32_t>(maxPacketsPerPull_ * kPacketFrames);
    frameCount = juce::jmin(frameCount, maxFrames);

    hdlnet::AudioPullPayload pull{};
    pull.request_id = pullRequestId_.fetch_add(1) + 1;
    pull.frame_count = frameCount;
    pull.host_fill = static_cast<uint32_t>(audioFifo_.getNumReady());
    pull.host_target = static_cast<uint32_t>(targetFillSamples());

    std::array<uint8_t, 64> out{};
    const uint32_t seq = seq_.fetch_add(1) + 1;
    const size_t len = hdlnet::encodeAudioPull(out.data(), seq, pull);
    socket.write(host, static_cast<int>(ctrlPort), out.data(), static_cast<int>(len));
    pulls_.fetch_add(1);
    pullInFlight_ = true;
    lastPullUs_ = nowUs();
}

void NetBridge::maybeRequestAudio(juce::DatagramSocket& socket) {
    if (!connected_.load() || muted_.load()) {
        return;
    }
    const uint64_t t = nowUs();
    if (pullInFlight_ && t - lastPullUs_ > 80'000) {
        pullInFlight_ = false;
    }
    if (pullInFlight_) {
        return;
    }

    const int fill = audioFifo_.getNumReady();
    const int minReserve = effectiveMinReservePackets() * kPacketFrames;
    const int targetFill = targetFillSamples();
    const int warmup = warmupFillSamples();

    if (!primed_) {
        if (fill < warmup) {
            const uint32_t need = static_cast<uint32_t>(juce::jmax(warmup - fill, kPacketFrames));
            sendPull(socket, need);
        }
        return;
    }

    if (fill < minReserve) {
        int need = targetFill - fill;
        need = juce::jmax(need, blockSize_);
        need = juce::jmin(need, maxPacketsPerPull_ * kPacketFrames);
        need = juce::jmax(need, kPacketFrames);
        sendPull(socket, static_cast<uint32_t>(need));
    }
}

void NetBridge::runAutoTune(uint64_t nowUs) {
    if (!autoTune_ || muted_.load()) {
        return;
    }
    if (nowUs - lastAutoTuneUs_ < 2'000'000) {
        return;
    }
    lastAutoTuneUs_ = nowUs;

    const int underruns = underruns_.load();
    const int deltaUnderruns = underruns - underrunsAtLastTune_;
    underrunsAtLastTune_ = underruns;

    if (deltaUnderruns > 0) {
        targetReservePackets_ = juce::jmin(kMaxReservePackets, targetReservePackets_ + 1);
        minReservePackets_ = juce::jmin(kMaxReservePackets - 2, minReservePackets_ + 1);
        return;
    }

    const auto quality = deliveryMonitor_.getQuality();
    if (quality == DeliveryQuality::Bursty) {
        if (targetReservePackets_ < kMaxReservePackets) {
            targetReservePackets_ = juce::jmin(kMaxReservePackets, targetReservePackets_ + 1);
        }
        return;
    }

    if (quality != DeliveryQuality::Smooth) {
        return;
    }
    if (!deliveryMonitor_.canDecreaseReserve(nowUs)) {
        return;
    }
    if (nowUs - lastDecreaseUs_ < 10'000'000) {
        return;
    }

    const int fill = audioFifo_.getNumReady();
    if (fill > targetFillSamples() + 2 * kPacketFrames &&
        targetReservePackets_ > minReservePackets_ + 2) {
        targetReservePackets_ = juce::jmax(minReservePackets_ + 2, targetReservePackets_ - 1);
        lastDecreaseUs_ = nowUs;
    }
}

void NetBridge::handleControlPacket(const uint8_t* data, int size) {
    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    if (!hdlnet::readControlHeader(data, static_cast<size_t>(size), hdr, type)) {
        return;
    }

    if (type == hdlnet::PacketType::Ack) {
        const uint8_t* payload = data + sizeof(hdlnet::ControlHeader);
        hdlnet::AckPayload ack{};
        if (hdlnet::decodeAck(payload, ack)) {
            engineCaps_.store(ack.caps);
        }
    }

    if (type == hdlnet::PacketType::Ack || type == hdlnet::PacketType::Pong) {
        const uint64_t t = nowUs();
        noteActivity(t);
        if (!connected_.load()) {
            connectTimeUs_ = t;
        }
        connected_.store(true);
        pullInFlight_ = false;
    }
}

void NetBridge::pushAudioSamples(const int16_t* interleaved, int frames, int channels) {
    const uint64_t t = nowUs();
    connected_.store(true);
    noteActivity(t);
    pullInFlight_ = false;
    if (!muted_.load()) {
        deliveryMonitor_.recordArrival(t);
    }
    constexpr float kScale = 1.0f / 32768.0f;

    int frameOffset = 0;
    int remaining = frames;
    while (remaining > 0) {
        int start1 = 0;
        int size1 = 0;
        int start2 = 0;
        int size2 = 0;
        audioFifo_.prepareToWrite(remaining, start1, size1, start2, size2);
        const int canWrite = size1 + size2;
        if (canWrite <= 0) {
            break;
        }

        for (int i = 0; i < size1; ++i) {
            const int frame = frameOffset + i;
            const int16_t l = interleaved[frame * channels];
            const int16_t r = channels > 1 ? interleaved[frame * channels + 1] : l;
            audioLeft_[static_cast<size_t>(start1 + i)] = static_cast<float>(l) * kScale;
            audioRight_[static_cast<size_t>(start1 + i)] = static_cast<float>(r) * kScale;
        }
        for (int i = 0; i < size2; ++i) {
            const int frame = frameOffset + size1 + i;
            const int16_t l = interleaved[frame * channels];
            const int16_t r = channels > 1 ? interleaved[frame * channels + 1] : l;
            audioLeft_[static_cast<size_t>(start2 + i)] = static_cast<float>(l) * kScale;
            audioRight_[static_cast<size_t>(start2 + i)] = static_cast<float>(r) * kScale;
        }

        audioFifo_.finishedWrite(canWrite);
        frameOffset += canWrite;
        remaining -= canWrite;
    }
}

void NetBridge::pushInputAudio(const float* left, const float* right, int numSamples) {
    if (!supportsAudioPush() || numSamples <= 0) {
        return;
    }

    int start1 = 0;
    int size1 = 0;
    int start2 = 0;
    int size2 = 0;
    pushAudioFifo_.prepareToWrite(numSamples, start1, size1, start2, size2);
    const int canWrite = size1 + size2;
    if (canWrite <= 0) {
        return;
    }

    int written = 0;
    for (int i = 0; i < size1; ++i) {
        pushLeft_[static_cast<size_t>(start1 + i)] = left[written];
        pushRight_[static_cast<size_t>(start1 + i)] = right[written];
        ++written;
    }
    for (int i = 0; i < size2; ++i) {
        pushLeft_[static_cast<size_t>(start2 + i)] = left[written];
        pushRight_[static_cast<size_t>(start2 + i)] = right[written];
        ++written;
    }
    pushAudioFifo_.finishedWrite(canWrite);
    pushAudioEvent_.signal();
}

void NetBridge::sendAudioPush(juce::DatagramSocket& socket,
                              const int16_t* interleaved,
                              int frames,
                              int channels) {
    juce::String host;
    uint16_t ctrlPort = controlPort_;
    {
        juce::ScopedLock lock(settingsLock_);
        host = engineHost_;
    }
    if (host.isEmpty() || frames <= 0) {
        return;
    }

    std::array<uint8_t, hdlnet::kMaxAudioPacketBytes + 64> out{};
    const uint32_t seq = seq_.fetch_add(1) + 1;
    const size_t len = hdlnet::encodeAudioPush(out.data(),
                                               seq,
                                               nowUs(),
                                               static_cast<uint16_t>(frames),
                                               static_cast<uint8_t>(channels),
                                               interleaved);
    socket.write(host, static_cast<int>(ctrlPort), out.data(), static_cast<int>(len));
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
    lastHelloUs_ = nowUs();

    std::array<uint8_t, hdlnet::kMaxAudioPacketBytes> buffer{};
    std::array<int16_t, hdlnet::kMaxAudioFrames * hdlnet::kMaxAudioChannels> pushInterleaved{};
    uint64_t lastQualityTickUs = nowUs();

    while (running_.load() && !threadShouldExit()) {
        if (settingsChanged_.wait(1)) {
            sendHello(controlSocket);
            lastHelloUs_ = nowUs();
        }

        const uint64_t t = nowUs();
        checkConnectionTimeout(t);

        if (!connected_.load() && t - lastHelloUs_ >= kHelloIntervalUs) {
            sendHello(controlSocket);
            lastHelloUs_ = t;
        }

        if (!muted_.load() && t - lastQualityTickUs >= 1'000'000) {
            deliveryMonitor_.tickWindow(t);
            runAutoTune(t);
            lastQualityTickUs = t;
        }

        maybeRequestAudio(controlSocket);

        if (supportsAudioPush() && pushAudioFifo_.getNumReady() > 0) {
            const int available = pushAudioFifo_.getNumReady();
            const int frames = juce::jmin(available, static_cast<int>(hdlnet::kMaxAudioFrames));
            int start1 = 0;
            int size1 = 0;
            int start2 = 0;
            int size2 = 0;
            pushAudioFifo_.prepareToRead(frames, start1, size1, start2, size2);
            int outIdx = 0;
            for (int i = 0; i < size1; ++i) {
                pushInterleaved[static_cast<size_t>(outIdx) * 2] = static_cast<int16_t>(
                    juce::jlimit(-1.0f, 1.0f, pushLeft_[static_cast<size_t>(start1 + i)]) * 32767.0f);
                pushInterleaved[static_cast<size_t>(outIdx) * 2 + 1] = static_cast<int16_t>(
                    juce::jlimit(-1.0f, 1.0f, pushRight_[static_cast<size_t>(start1 + i)]) * 32767.0f);
                ++outIdx;
            }
            for (int i = 0; i < size2; ++i) {
                pushInterleaved[static_cast<size_t>(outIdx) * 2] = static_cast<int16_t>(
                    juce::jlimit(-1.0f, 1.0f, pushLeft_[static_cast<size_t>(start2 + i)]) * 32767.0f);
                pushInterleaved[static_cast<size_t>(outIdx) * 2 + 1] = static_cast<int16_t>(
                    juce::jlimit(-1.0f, 1.0f, pushRight_[static_cast<size_t>(start2 + i)]) * 32767.0f);
                ++outIdx;
            }
            pushAudioFifo_.finishedRead(outIdx);
            if (outIdx > 0) {
                sendAudioPush(controlSocket, pushInterleaved.data(), outIdx, 2);
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

            std::array<uint8_t, hdlnet::kMaxMidiBytes + 64> out{};
            const uint32_t seq = seq_.fetch_add(1) + 1;
            const uint64_t ts = event.timestampUs != 0 ? event.timestampUs : nowUs();
            const size_t len = hdlnet::encodeMidi(out.data(),
                                                  hdlnet::PacketType::MidiHostToEngine,
                                                  seq,
                                                  ts,
                                                  event.bytes.data(),
                                                  static_cast<uint16_t>(event.bytes.size()));

            controlSocket.write(host, static_cast<int>(ctrlPort), out.data(), static_cast<int>(len));
        }

        juce::String sender;
        int senderPort = 0;
        while (true) {
            const int ctrlBytes =
                controlSocket.read(buffer.data(), static_cast<int>(buffer.size()), false, sender,
                                   senderPort);
            if (ctrlBytes <= 0) {
                break;
            }
            handleControlPacket(buffer.data(), ctrlBytes);
        }

        while (true) {
            const int audioBytes =
                audioSocket.read(buffer.data(), static_cast<int>(buffer.size()), false, sender,
                                 senderPort);
            if (audioBytes <= 0) {
                break;
            }
            hdlnet::AudioHeader hdr{};
            size_t payloadBytes = 0;
            if (hdlnet::decodeAudioHeader(buffer.data(), static_cast<size_t>(audioBytes), hdr,
                                          payloadBytes)) {
                const auto* samples =
                    reinterpret_cast<const int16_t*>(buffer.data() + sizeof(hdlnet::AudioHeader));
                pushAudioSamples(samples, hdr.frame_count, hdr.channels);
            }
        }

        maybeRequestAudio(controlSocket);
    }
}
