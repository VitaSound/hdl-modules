#include "input_udp.h"

#include "net_socket.h"
#include "protocol/hdl_net.h"

#include <array>
#include <chrono>
#include <iostream>
#include <vector>

namespace {
constexpr size_t kRecvBufferSize = 2048;

void printUdpDebug(const char* eventType, bool gate, int note, int velocity) {
    std::cerr << "[udp] " << eventType
              << " | NOTE " << note
              << " | VELOCITY " << velocity
              << " | GATE " << (gate ? "ON" : "OFF")
              << "\n";
    std::cerr.flush();
}

bool anyPressed(const std::array<bool, 128>& pressed) {
    for (bool v : pressed) {
        if (v) {
            return true;
        }
    }
    return false;
}

bool generateAndSendAudio(UdpSocket& audioSock,
                          SynthCore& synth,
                          SharedState& state,
                          const std::string& plugin_host,
                          uint16_t plugin_port,
                          uint32_t total_frames,
                          uint16_t packet_frames,
                          uint8_t channels,
                          std::vector<int16_t>& mono,
                          std::vector<int16_t>& interleaved,
                          std::array<uint8_t, hdlnet::kMaxAudioPacketBytes>& packet,
                          uint32_t& audio_seq,
                          uint64_t& sample_index,
                          uint32_t effective_rate) {
    uint32_t remaining = total_frames;
    while (remaining > 0) {
        const uint16_t block_frames =
            static_cast<uint16_t>(remaining > packet_frames ? packet_frames : remaining);

        synthGenerate(synth, state, mono.data(), block_frames);

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
} // namespace

std::thread startUdpInput(const UdpInputConfig& cfg,
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
            std::cerr << "UDP input bind failed on " << cfg.bindHost << ":" << cfg.controlPort
                      << "\n";
            return;
        }
        ctrlSock.setRecvTimeoutMs(200);
        audioSock.setSendBufferBytes(256 * 1024);

        const uint16_t packet_frames = cfg.packetFrames;
        const uint8_t channels = cfg.audioChannels;
        synth.channels = 1;

        std::cerr << "UDP control listening on " << cfg.bindHost << ":" << cfg.controlPort
                  << " (pull mode, packet_frames=" << packet_frames << ")\n";

        std::array<bool, 128> pressed{};
        std::array<uint8_t, kRecvBufferSize> buffer{};
        uint32_t ack_seq = 0;
        uint32_t audio_seq = 0;
        uint64_t sample_index = 0;

        std::vector<int16_t> mono(packet_frames);
        std::vector<int16_t> interleaved(packet_frames * channels);
        std::array<uint8_t, hdlnet::kMaxAudioPacketBytes> packet{};

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

                hdlnet::AckPayload ack{};
                ack.sample_rate = hello.sample_rate;
                ack.engine_ssrc = cfg.engineSsrc;
                ack.packet_frames = packet_frames;
                ack.max_frames_per_pull = cfg.maxFramesPerPull;
                std::array<uint8_t, 64> out{};
                const size_t out_len = hdlnet::encodeAck(out.data(), ++ack_seq, ack);
                UdpEndpoint dest{src.host, src.port};
                ctrlSock.sendTo(out.data(), out_len, dest);

                std::cerr << "[udp] HELLO from " << src.host << ":" << src.port
                          << " sr=" << hello.sample_rate
                          << " audio_port=" << hello.audio_port
                          << " pull mode\n";
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
                    synth.sampleRate = stream_rate;
                }
                const uint32_t effective_rate = stream_rate > 0 ? stream_rate : synth.sampleRate;

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
                                     plugin_host,
                                     plugin_port,
                                     frame_count,
                                     packet_frames,
                                     channels,
                                     mono,
                                     interleaved,
                                     packet,
                                     audio_seq,
                                     sample_index,
                                     effective_rate);
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
            case hdlnet::PacketType::NoteOn: {
                hdlnet::NotePayload note{};
                if (!hdlnet::decodeNote(payload, note)) {
                    break;
                }
                if (note.note < 128) {
                    if (note.velocity > 0) {
                        pressed[note.note] = true;
                        state.note.store(note.note, std::memory_order_relaxed);
                    } else {
                        pressed[note.note] = false;
                    }
                    const bool any = anyPressed(pressed);
                    state.gate.store(any, std::memory_order_relaxed);
                    printUdpDebug(note.velocity > 0 ? "NOTE ON" : "NOTE OFF", any, note.note,
                                  note.velocity);
                }
                break;
            }
            case hdlnet::PacketType::NoteOff: {
                hdlnet::NotePayload note{};
                if (!hdlnet::decodeNote(payload, note)) {
                    break;
                }
                if (note.note < 128) {
                    pressed[note.note] = false;
                    const bool any = anyPressed(pressed);
                    state.gate.store(any, std::memory_order_relaxed);
                    printUdpDebug("NOTE OFF", any, note.note, note.velocity);
                }
                break;
            }
            case hdlnet::PacketType::AllNotesOff: {
                pressed.fill(false);
                state.gate.store(false, std::memory_order_relaxed);
                printUdpDebug("ALL NOTES OFF", false, -1, 0);
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
