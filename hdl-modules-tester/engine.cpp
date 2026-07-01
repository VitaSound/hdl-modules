#include "engine.h"

#include "midi_events.h"
#include "net_socket.h"
#include "protocol/hdl_net.h"
#include "synth_core.h"

#include <array>
#include <chrono>
#include <iostream>
#include <vector>

namespace {
constexpr size_t kRecvBufferSize = 2048;
constexpr size_t kAudioInRingCapacity = 48000 * 4;

struct AudioInRing {
    std::vector<int16_t> buf;
    size_t write_pos = 0;
    size_t read_pos = 0;
    size_t count = 0;

    AudioInRing() { buf.resize(kAudioInRingCapacity); }

    void reset() {
        write_pos = 0;
        read_pos = 0;
        count = 0;
    }

    void push(const int16_t* samples, uint32_t frames, uint8_t channels) {
        for (uint32_t i = 0; i < frames; ++i) {
            const int16_t sample = samples[static_cast<size_t>(i) * channels];
            if (count >= kAudioInRingCapacity) {
                read_pos = (read_pos + 1) % kAudioInRingCapacity;
                --count;
            }
            buf[write_pos] = sample;
            write_pos = (write_pos + 1) % kAudioInRingCapacity;
            ++count;
        }
    }

    void pop(int16_t* out, uint32_t frames) {
        for (uint32_t i = 0; i < frames; ++i) {
            if (count == 0) {
                out[i] = 0;
                continue;
            }
            out[i] = buf[read_pos];
            read_pos = (read_pos + 1) % kAudioInRingCapacity;
            --count;
        }
    }
};

bool generateAndSendAudio(UdpSocket& audioSock,
                          SynthCore& synth,
                          SharedState& state,
                          AudioInRing& audio_in_ring,
                          bool use_audio_push,
                          const std::string& plugin_host,
                          uint16_t plugin_port,
                          uint32_t total_frames,
                          uint16_t packet_frames,
                          uint8_t channels,
                          std::vector<int16_t>& mono,
                          std::vector<int16_t>& input_mono,
                          std::vector<int16_t>& interleaved,
                          std::array<uint8_t, hdlnet::kMaxAudioPacketBytes>& packet,
                          uint32_t& audio_seq,
                          uint64_t& sample_index,
                          uint32_t effective_rate) {
    uint32_t remaining = total_frames;
    while (remaining > 0) {
        const uint16_t block_frames =
            static_cast<uint16_t>(remaining > packet_frames ? packet_frames : remaining);

        if (use_audio_push) {
            audio_in_ring.pop(input_mono.data(), block_frames);
        }

        synthGeneratePull(synth,
                          state,
                          mono.data(),
                          block_frames,
                          use_audio_push ? input_mono.data() : nullptr);

        for (uint16_t i = 0; i < block_frames; ++i) {
            for (uint8_t ch = 0; ch < channels; ++ch) {
                interleaved[static_cast<size_t>(i) * channels + ch] = mono[i];
            }
        }

        const uint64_t timestamp_us = sample_index * 1'000'000 / effective_rate;
        const size_t packet_len = hdlnet::encodeAudio(packet.data(),
                                                        ++audio_seq,
                                                        timestamp_us,
                                                        block_frames,
                                                        channels,
                                                        interleaved.data());

        const ssize_t sent =
            audioSock.sendTo(packet.data(), packet_len, UdpEndpoint{plugin_host, plugin_port});
        if (sent < 0) {
            std::cerr << "UDP audio send failed to " << plugin_host << ":" << plugin_port << "\n";
            return false;
        }

        sample_index += block_frames;
        remaining -= block_frames;
    }
    return true;
}

void sendMidiOutIfAny(UdpSocket& ctrlSock, SynthCore& synth, const UdpEndpoint& dest) {
    std::vector<uint8_t> midi_out;
    if (!synthDrainMidiOut(synth, midi_out) || midi_out.empty()) {
        return;
    }
    std::array<uint8_t, hdlnet::kMaxMidiBytes + 64> out{};
    static uint32_t midi_seq = 0;
    const size_t out_len = hdlnet::encodeMidi(out.data(),
                                                hdlnet::PacketType::MidiEngineToHost,
                                                ++midi_seq,
                                                0,
                                                midi_out.data(),
                                                static_cast<uint16_t>(midi_out.size()));
    ctrlSock.sendTo(out.data(), out_len, dest);
}
} // namespace

std::thread startEngine(const EngineConfig& cfg,
                        SharedState& state,
                        UdpSessionState& session,
                        SynthCore& synth) {
    return std::thread([cfg, &state, &session, &synth]() {
        UdpSocket ctrlSock;
        UdpSocket audioSock;
        if (!ctrlSock.open() || !audioSock.open()) {
            std::cerr << "UDP socket open failed\n";
            return;
        }
        if (!ctrlSock.bind(cfg.bindHost, cfg.controlPort)) {
            std::cerr << "UDP bind failed on " << cfg.bindHost << ":" << cfg.controlPort << "\n";
            return;
        }
        ctrlSock.setRecvTimeoutMs(200);
        audioSock.setSendBufferBytes(256 * 1024);

        const uint16_t packet_frames = cfg.packetFrames;
        const uint8_t channels = cfg.audioChannels;

        std::cerr << "UDP listening on " << cfg.bindHost << ":" << cfg.controlPort
                  << " (pull mode, packet_frames=" << packet_frames << ")\n";

        std::array<uint8_t, kRecvBufferSize> buffer{};
        uint32_t ack_seq = 0;
        uint32_t audio_seq = 0;
        uint64_t sample_index = 0;
        UdpEndpoint last_plugin{};

        std::vector<int16_t> mono(packet_frames);
        std::vector<int16_t> input_mono(packet_frames);
        std::vector<int16_t> interleaved(packet_frames * channels);
        std::array<uint8_t, hdlnet::kMaxAudioPacketBytes> packet{};
        AudioInRing audio_in_ring;
        const bool use_audio_push = (cfg.caps & hdlnet::kCapAudioPush) != 0;

        while (state.running.load(std::memory_order_relaxed)) {
            UdpEndpoint src;
            const ssize_t n = ctrlSock.recvFrom(buffer.data(), buffer.size(), src);
            if (n <= 0) {
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
                continue;
            }

            hdlnet::ControlHeader hdr{};
            hdlnet::PacketType type{};
            if (!hdlnet::readControlHeader(buffer.data(), static_cast<size_t>(n), hdr, type)) {
                continue;
            }

            const uint8_t* payload = buffer.data() + sizeof(hdlnet::ControlHeader);
            last_plugin = src;

            switch (type) {
            case hdlnet::PacketType::Hello: {
                hdlnet::HelloPayload hello{};
                if (!hdlnet::decodeHello(payload, hello)) {
                    break;
                }
                session.sample_rate.store(hello.sample_rate, std::memory_order_relaxed);
                session.block_size.store(hello.block_size, std::memory_order_relaxed);
                session.plugin_ssrc.store(hello.plugin_ssrc, std::memory_order_relaxed);
                session.setPlugin(src.host, hello.audio_port);
                session.connected.store(true, std::memory_order_relaxed);

                state.gate.store(false, std::memory_order_relaxed);
                state.note.store(-1, std::memory_order_relaxed);
                audio_seq = 0;
                sample_index = 0;
                synthResetPullTiming(synth);
                audio_in_ring.reset();

                synthOnSessionStart(synth);

                hdlnet::AckPayload ack{};
                ack.sample_rate = hello.sample_rate;
                ack.engine_ssrc = cfg.engineSsrc;
                ack.packet_frames = packet_frames;
                ack.max_frames_per_pull = cfg.maxFramesPerPull;
                ack.caps = cfg.caps;
                std::array<uint8_t, 64> out{};
                const size_t out_len = hdlnet::encodeAck(out.data(), ++ack_seq, ack);
                UdpEndpoint dest{src.host, src.port};
                ctrlSock.sendTo(out.data(), out_len, dest);

                std::cerr << "[udp] HELLO from " << src.host << ":" << src.port
                          << " sr=" << hello.sample_rate
                          << " audio_port=" << hello.audio_port << "\n";
                break;
            }
            case hdlnet::PacketType::AudioPull: {
                if (!session.connected.load(std::memory_order_relaxed)) {
                    break;
                }
                hdlnet::AudioPullPayload pull{};
                if (!hdlnet::decodeAudioPull(payload, pull)) {
                    break;
                }

                std::string plugin_host;
                uint16_t plugin_port = 0;
                if (!session.getPlugin(plugin_host, plugin_port)) {
                    break;
                }

                const uint32_t stream_rate = session.sample_rate.load(std::memory_order_relaxed);
                if (stream_rate > 0) {
                    synthSetSampleRate(synth, stream_rate);
                }
                const uint32_t effective_rate = stream_rate > 0 ? stream_rate : synthGetSampleRate(synth);

                uint32_t frame_count = pull.frame_count;
                if (frame_count == 0) {
                    break;
                }
                if (frame_count > cfg.maxFramesPerPull) {
                    frame_count = cfg.maxFramesPerPull;
                }

                generateAndSendAudio(audioSock,
                                     synth,
                                     state,
                                     audio_in_ring,
                                     use_audio_push,
                                     plugin_host,
                                     plugin_port,
                                     frame_count,
                                     packet_frames,
                                     channels,
                                     mono,
                                     input_mono,
                                     interleaved,
                                     packet,
                                     audio_seq,
                                     sample_index,
                                     effective_rate);
                sendMidiOutIfAny(ctrlSock, synth, last_plugin);
                break;
            }
            case hdlnet::PacketType::AudioPush: {
                if (!use_audio_push) {
                    break;
                }
                hdlnet::AudioHeader push_hdr{};
                size_t push_payload_bytes = 0;
                if (!hdlnet::decodeAudioPushPayload(payload,
                                                    hdr.payload_len,
                                                    push_hdr,
                                                    push_payload_bytes)) {
                    break;
                }
                const auto* push_samples =
                    reinterpret_cast<const int16_t*>(payload + sizeof(hdlnet::AudioHeader));
                audio_in_ring.push(push_samples, push_hdr.frame_count, push_hdr.channels);
                break;
            }
            case hdlnet::PacketType::Ping: {
                uint64_t ts = 0;
                hdlnet::decodeTimestamp(payload, ts);
                std::array<uint8_t, 64> out{};
                const size_t out_len =
                    hdlnet::encodePingPong(out.data(), hdlnet::PacketType::Pong, hdr.seq, ts);
                ctrlSock.sendTo(out.data(), out_len, UdpEndpoint{src.host, src.port});
                break;
            }
            case hdlnet::PacketType::MidiHostToEngine: {
                uint64_t ts = 0;
                const uint8_t* midi_data = nullptr;
                uint16_t midi_len = 0;
                if (!hdlnet::decodeMidi(payload, hdr.payload_len, ts, midi_data, midi_len)) {
                    break;
                }
                if (midi_len > 0 && midi_data != nullptr) {
                    synthPostMidiBytes(synth, midi_data, midi_len);
                }
                break;
            }
            default:
                break;
            }
        }

        state.gate.store(false, std::memory_order_relaxed);
        state.note.store(-1, std::memory_order_relaxed);
        session.connected.store(false, std::memory_order_relaxed);
    });
}
