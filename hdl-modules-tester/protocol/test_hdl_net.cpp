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

static void testNoteAndAudio() {
    uint8_t buf[256]{};
    hdlnet::NotePayload note_in{123456789ull, 60, 100};
    const size_t note_len =
        hdlnet::encodeNote(buf, hdlnet::PacketType::NoteOn, 42, note_in);

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    CHECK(hdlnet::readControlHeader(buf, note_len, hdr, type));
    CHECK(type == hdlnet::PacketType::NoteOn);

    hdlnet::NotePayload note_out{};
    CHECK(hdlnet::decodeNote(buf + sizeof(hdlnet::ControlHeader), note_out));
    CHECK(note_out.timestamp_us == 123456789ull);
    CHECK(note_out.note == 60);
    CHECK(note_out.velocity == 100);

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

static void testControlChangeAndPitchBend() {
    uint8_t buf[128]{};

    hdlnet::ControlChangePayload cc_in{987654321ull, 16, 64};
    const size_t cc_len = hdlnet::encodeControlChange(buf, 11, cc_in);

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    CHECK(hdlnet::readControlHeader(buf, cc_len, hdr, type));
    CHECK(type == hdlnet::PacketType::ControlChange);

    hdlnet::ControlChangePayload cc_out{};
    CHECK(hdlnet::decodeControlChange(buf + sizeof(hdlnet::ControlHeader), cc_out));
    CHECK(cc_out.timestamp_us == 987654321ull);
    CHECK(cc_out.cc == 16);
    CHECK(cc_out.value == 64);

    hdlnet::PitchBendPayload bend_in{111222333ull, 8192};
    const size_t bend_len = hdlnet::encodePitchBend(buf, 12, bend_in);
    CHECK(hdlnet::readControlHeader(buf, bend_len, hdr, type));
    CHECK(type == hdlnet::PacketType::PitchBend);

    hdlnet::PitchBendPayload bend_out{};
    CHECK(hdlnet::decodePitchBend(buf + sizeof(hdlnet::ControlHeader), bend_out));
    CHECK(bend_out.timestamp_us == 111222333ull);
    CHECK(bend_out.value == 8192);
}

int main() {
    testHelloRoundTrip();
    testAckAndAudioPull();
    testNoteAndAudio();
    testControlChangeAndPitchBend();
    if (g_failures == 0) {
        std::printf("hdl_net tests: OK\n");
        return 0;
    }
    std::printf("hdl_net tests: %d failure(s)\n", g_failures);
    return 1;
}
