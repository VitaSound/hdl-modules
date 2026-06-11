#include "output_udp.h"

#include "net_socket.h"
#include "protocol/hdl_net.h"

#include <array>
#include <chrono>
#include <iostream>
#include <thread>
#include <vector>

namespace {
uint64_t nowUs() {
    using clock = std::chrono::steady_clock;
    return static_cast<uint64_t>(
        std::chrono::duration_cast<std::chrono::microseconds>(clock::now().time_since_epoch())
            .count());
}

bool sendAudioBlock(UdpSocket& sock,
                    SynthCore& synth,
                    SharedState& state,
                    const std::string& plugin_host,
                    uint16_t plugin_port,
                    uint16_t block_frames,
                    uint8_t channels,
                    std::vector<int16_t>& mono,
                    std::vector<int16_t>& interleaved,
                    std::array<uint8_t, hdlnet::kMaxAudioPacketBytes>& packet,
                    uint32_t& seq,
                    uint64_t& sample_index,
                    uint32_t effective_rate) {
    synthGenerate(synth, state, mono.data(), block_frames);

    for (uint16_t i = 0; i < block_frames; ++i) {
        for (uint8_t ch = 0; ch < channels; ++ch) {
            interleaved[static_cast<size_t>(i) * channels + ch] = mono[i];
        }
    }

    const uint64_t timestamp_us = sample_index * 1'000'000 / effective_rate;
    const size_t packet_len = hdlnet::encodeAudio(packet.data(),
                                                    ++seq,
                                                    timestamp_us,
                                                    block_frames,
                                                    channels,
                                                    interleaved.data());

    const ssize_t sent =
        sock.sendTo(packet.data(), packet_len, UdpEndpoint{plugin_host, plugin_port});
    if (sent < 0) {
        std::cerr << "UDP audio send failed to " << plugin_host << ":" << plugin_port << "\n";
        return false;
    }

    sample_index += block_frames;
    return true;
}
} // namespace

int runUdpOutput(SynthCore& synth,
                 SharedState& state,
                 UdpSessionState& session,
                 const UdpOutputConfig& cfg) {
    UdpSocket sock;
    if (!sock.open()) {
        return 1;
    }
    sock.setSendBufferBytes(256 * 1024);

    const uint16_t block_frames = cfg.blockFrames;
    const uint8_t channels = cfg.channels;
    synth.channels = 1;

    std::vector<int16_t> mono(block_frames);
    std::vector<int16_t> interleaved(block_frames * channels);
    std::array<uint8_t, hdlnet::kMaxAudioPacketBytes> packet{};

    uint32_t seq = 0;
    uint64_t sample_index = 0;
    using clock = std::chrono::steady_clock;
    auto next_tick = clock::now();

    std::cerr << "UDP audio output: block=" << block_frames
              << " sr=" << synth.sampleRate
              << " ch=" << static_cast<int>(channels) << "\n";

    while (state.running.load(std::memory_order_relaxed)) {
        std::string plugin_host;
        uint16_t plugin_port = 0;
        if (!session.getPlugin(plugin_host, plugin_port)) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            next_tick = clock::now();
            continue;
        }

        const uint32_t stream_rate = session.sample_rate.load(std::memory_order_relaxed);
        if (stream_rate > 0) {
            synth.sampleRate = stream_rate;
        }
        const uint32_t effective_rate = stream_rate > 0 ? stream_rate : synth.sampleRate;
        const auto frame_period = std::chrono::microseconds(
            static_cast<int64_t>(1'000'000) * block_frames / effective_rate);

        next_tick += frame_period;

        if (!sendAudioBlock(sock,
                            synth,
                            state,
                            plugin_host,
                            plugin_port,
                            block_frames,
                            channels,
                            mono,
                            interleaved,
                            packet,
                            seq,
                            sample_index,
                            effective_rate)) {
            return 1;
        }

        auto now = clock::now();
        // Catch up when synth/network fell behind — burst extra blocks to refill VST jitter FIFO.
        while (now > next_tick && state.running.load(std::memory_order_relaxed)) {
            next_tick += frame_period;
            if (!sendAudioBlock(sock,
                                synth,
                                state,
                                plugin_host,
                                plugin_port,
                                block_frames,
                                channels,
                                mono,
                                interleaved,
                                packet,
                                seq,
                                sample_index,
                                effective_rate)) {
                return 1;
            }
            now = clock::now();
        }

        if (now < next_tick) {
            std::this_thread::sleep_until(next_tick);
        } else {
            next_tick = now;
        }
    }

    return 0;
}
