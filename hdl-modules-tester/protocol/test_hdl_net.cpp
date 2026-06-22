#include "protocol/hdl_net.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

static int g_failures = 0;

#define CHECK(cond)                                                                        \
    do {                                                                                   \
        if (!(cond)) {                                                                     \
            std::fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);           \
            ++g_failures;                                                                  \
        }                                                                                  \
    } while (0)

static void testHelloRoundTrip() {
    uint8_t buf[128]{};
    hdlnet::HelloPayload in{48000,
                            512,
                            0x12345678u,
                            5005,
                            hdlnet::kSessionModePull,
                            0,
                            256,
                            16,
                            6,
                            12};
    const size_t len = hdlnet::encodeHello(buf, 7, in);

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    CHECK(hdlnet::readControlHeader(buf, len, hdr, type));
    CHECK(type == hdlnet::PacketType::Hello);
    CHECK(hdr.seq == 7);

    hdlnet::HelloPayload out{};
    CHECK(hdlnet::decodeHello(buf + sizeof(hdlnet::ControlHeader), out));
    CHECK(out.sample_rate == 48000);
    CHECK(out.block_size == 512);
    CHECK(out.plugin_ssrc == 0x12345678u);
    CHECK(out.audio_port == 5005);
    CHECK(out.session_mode == hdlnet::kSessionModePull);
    CHECK(out.packet_frames == 256);
    CHECK(out.initial_warmup_packets == 16);
    CHECK(out.min_reserve_packets == 6);
    CHECK(out.target_reserve_packets == 12);
}

static void testAckAndAudioPull() {
    uint8_t buf[128]{};
    hdlnet::AckPayload ack_in{48000, 0x454E474Eu, 256, hdlnet::kDefaultMaxFramesPerPull};
    const size_t ack_len = hdlnet::encodeAck(buf, 3, ack_in);

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    CHECK(hdlnet::readControlHeader(buf, ack_len, hdr, type));
    CHECK(type == hdlnet::PacketType::Ack);

    hdlnet::AckPayload ack_out{};
    CHECK(hdlnet::decodeAck(buf + sizeof(hdlnet::ControlHeader), ack_out));
    CHECK(ack_out.sample_rate == 48000);
    CHECK(ack_out.engine_ssrc == 0x454E474Eu);
    CHECK(ack_out.packet_frames == 256);
    CHECK(ack_out.max_frames_per_pull == hdlnet::kDefaultMaxFramesPerPull);

    hdlnet::AudioPullPayload pull_in{42, 2048, 512, 3072};
    const size_t pull_len = hdlnet::encodeAudioPull(buf, 9, pull_in);
    CHECK(hdlnet::readControlHeader(buf, pull_len, hdr, type));
    CHECK(type == hdlnet::PacketType::AudioPull);

    hdlnet::AudioPullPayload pull_out{};
    CHECK(hdlnet::decodeAudioPull(buf + sizeof(hdlnet::ControlHeader), pull_out));
    CHECK(pull_out.request_id == 42);
    CHECK(pull_out.frame_count == 2048);
    CHECK(pull_out.host_fill == 512);
    CHECK(pull_out.host_target == 3072);
}

static void testMidiAndAudio() {
    uint8_t buf[256]{};
    const uint8_t midi_in[] = {0x90, 60, 100};
    const size_t midi_len =
        hdlnet::encodeMidi(buf,
                           hdlnet::PacketType::MidiHostToEngine,
                           42,
                           123456789ull,
                           midi_in,
                           static_cast<uint16_t>(sizeof(midi_in)));

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    CHECK(hdlnet::readControlHeader(buf, midi_len, hdr, type));
    CHECK(type == hdlnet::PacketType::MidiHostToEngine);

    uint64_t ts = 0;
    const uint8_t* midi_data = nullptr;
    uint16_t midi_out_len = 0;
    CHECK(hdlnet::decodeMidi(buf + sizeof(hdlnet::ControlHeader),
                             hdr.payload_len,
                             ts,
                             midi_data,
                             midi_out_len));
    CHECK(ts == 123456789ull);
    CHECK(midi_out_len == 3);
    CHECK(midi_data[0] == 0x90);
    CHECK(midi_data[1] == 60);
    CHECK(midi_data[2] == 100);

    std::vector<int16_t> samples{1000, -1000, 2000, -2000};
    const size_t audio_len =
        hdlnet::encodeAudio(buf, 99, 555ull, 2, 2, samples.data());

    hdlnet::AudioHeader audio_hdr{};
    size_t payload_bytes = 0;
    CHECK(hdlnet::decodeAudioHeader(buf, audio_len, audio_hdr, payload_bytes));
    CHECK(audio_hdr.seq == 99);
    CHECK(audio_hdr.timestamp_us == 555ull);
    CHECK(audio_hdr.frame_count == 2);
    CHECK(audio_hdr.channels == 2);
    CHECK(payload_bytes == 8);

    int16_t decoded[4]{};
    std::memcpy(decoded, buf + sizeof(hdlnet::AudioHeader), payload_bytes);
    CHECK(decoded[0] == 1000);
    CHECK(decoded[1] == -1000);
    CHECK(decoded[2] == 2000);
    CHECK(decoded[3] == -2000);
}

int main() {
    testHelloRoundTrip();
    testAckAndAudioPull();
    testMidiAndAudio();
    if (g_failures == 0) {
        std::printf("hdl_net tests: OK\n");
        return 0;
    }
    std::printf("hdl_net tests: %d failure(s)\n", g_failures);
    return 1;
}
