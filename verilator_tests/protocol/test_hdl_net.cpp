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
    hdlnet::HelloPayload in{48000, 256, 0x12345678u, 5005};
    const size_t len = hdlnet::encodeHello(buf, 7, in);

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    CHECK(hdlnet::readControlHeader(buf, len, hdr, type));
    CHECK(type == hdlnet::PacketType::Hello);
    CHECK(hdr.seq == 7);

    hdlnet::HelloPayload out{};
    CHECK(hdlnet::decodeHello(buf + sizeof(hdlnet::ControlHeader), out));
    CHECK(out.sample_rate == 48000);
    CHECK(out.block_size == 256);
    CHECK(out.plugin_ssrc == 0x12345678u);
    CHECK(out.audio_port == 5005);
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

int main() {
    testHelloRoundTrip();
    testNoteAndAudio();
    if (g_failures == 0) {
        std::printf("hdl_net tests: OK\n");
        return 0;
    }
    std::printf("hdl_net tests: %d failure(s)\n", g_failures);
    return 1;
}
