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
} // namespace

int runUdpOutput(SynthCore& synth,
                 SharedState& state,
                 UdpSessionState& session,
                 const UdpOutputConfig& cfg) {
    UdpSocket sock;
    if (!sock.open()) {
        return 1;
    }

    const uint16_t block_frames = cfg.blockFrames;
    const uint8_t channels = cfg.channels;
    synth.channels = 1;

    std::vector<int16_t> mono(block_frames);
    std::vector<int16_t> interleaved(block_frames * channels);
    std::array<uint8_t, hdlnet::kMaxAudioPacketBytes> packet{};

    uint32_t seq = 0;
    uint64_t sample_index = 0;

    std::cerr << "UDP audio output: block=" << block_frames
              << " sr=" << synth.sampleRate
              << " ch=" << static_cast<int>(channels) << "\n";

    while (state.running.load(std::memory_order_relaxed)) {
        std::string plugin_host;
        uint16_t plugin_port = 0;
        if (!session.getPlugin(plugin_host, plugin_port)) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            continue;
        }

        const uint32_t stream_rate = session.sample_rate.load(std::memory_order_relaxed);
        const uint32_t effective_rate = stream_rate > 0 ? stream_rate : synth.sampleRate;
        const auto frame_period = std::chrono::microseconds(
            static_cast<int64_t>(1'000'000) * block_frames / effective_rate);

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
            return 1;
        }

        sample_index += block_frames;
        std::this_thread::sleep_for(frame_period);
    }

    return 0;
}
