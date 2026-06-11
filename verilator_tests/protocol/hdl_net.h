#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace hdlnet {

constexpr uint32_t kMagicControl = 0x48444C4Du; // "HDLM"
constexpr uint32_t kMagicAudio = 0x48444C41u;   // "HDLA"
constexpr uint8_t kVersion = 1;

constexpr uint16_t kDefaultControlPort = 5004;
constexpr uint16_t kDefaultAudioPort = 5005;

constexpr uint16_t kMaxAudioFrames = 256;
constexpr uint16_t kMaxAudioChannels = 2;
constexpr size_t kAudioHeaderSize = 22;
constexpr size_t kMaxAudioPacketBytes =
    kAudioHeaderSize + kMaxAudioFrames * kMaxAudioChannels * sizeof(int16_t);

enum class PacketType : uint8_t {
    Hello = 1,
    Ack = 2,
    Ping = 3,
    Pong = 4,
    NoteOn = 5,
    NoteOff = 6,
    AllNotesOff = 7,
};

#pragma pack(push, 1)
struct ControlHeader {
    uint32_t magic;
    uint8_t version;
    uint8_t type;
    uint16_t payload_len;
    uint32_t seq;
};

struct HelloPayload {
    uint32_t sample_rate;
    uint16_t block_size;
    uint32_t plugin_ssrc;
    uint16_t audio_port;
};

struct AckPayload {
    uint32_t sample_rate;
    uint32_t engine_ssrc;
};

struct TimestampPayload {
    uint64_t timestamp_us;
};

struct NotePayload {
    uint64_t timestamp_us;
    uint8_t note;
    uint8_t velocity;
};

struct AudioHeader {
    uint32_t magic;
    uint8_t version;
    uint8_t reserved;
    uint32_t seq;
    uint64_t timestamp_us;
    uint16_t frame_count;
    uint8_t channels;
    uint8_t pad;
};
#pragma pack(pop)

inline uint16_t hostToBe16(uint16_t v) {
    return static_cast<uint16_t>((v >> 8) | (v << 8));
}

inline uint32_t hostToBe32(uint32_t v) {
    return ((v & 0x000000FFu) << 24) | ((v & 0x0000FF00u) << 8) |
           ((v & 0x00FF0000u) >> 8) | ((v & 0xFF000000u) >> 24);
}

inline uint64_t hostToBe64(uint64_t v) {
    return (static_cast<uint64_t>(hostToBe32(static_cast<uint32_t>(v & 0xFFFFFFFFu))) << 32) |
           hostToBe32(static_cast<uint32_t>(v >> 32));
}

inline uint16_t beToHost16(uint16_t v) { return hostToBe16(v); }
inline uint32_t beToHost32(uint32_t v) { return hostToBe32(v); }
inline uint64_t beToHost64(uint64_t v) { return hostToBe64(v); }

inline void writeControlHeader(uint8_t* out, PacketType type, uint32_t seq, uint16_t payload_len) {
    auto* hdr = reinterpret_cast<ControlHeader*>(out);
    hdr->magic = hostToBe32(kMagicControl);
    hdr->version = kVersion;
    hdr->type = static_cast<uint8_t>(type);
    hdr->payload_len = hostToBe16(payload_len);
    hdr->seq = hostToBe32(seq);
}

inline bool readControlHeader(const uint8_t* in, size_t len, ControlHeader& hdr, PacketType& type) {
    if (len < sizeof(ControlHeader)) {
        return false;
    }
    std::memcpy(&hdr, in, sizeof(ControlHeader));
    if (beToHost32(hdr.magic) != kMagicControl || hdr.version != kVersion) {
        return false;
    }
    type = static_cast<PacketType>(hdr.type);
    hdr.payload_len = beToHost16(hdr.payload_len);
    hdr.seq = beToHost32(hdr.seq);
    return len >= sizeof(ControlHeader) + hdr.payload_len;
}

inline size_t encodeHello(uint8_t* out, uint32_t seq, const HelloPayload& payload) {
    writeControlHeader(out, PacketType::Hello, seq, sizeof(HelloPayload));
    auto* p = reinterpret_cast<HelloPayload*>(out + sizeof(ControlHeader));
    p->sample_rate = hostToBe32(payload.sample_rate);
    p->block_size = hostToBe16(payload.block_size);
    p->plugin_ssrc = hostToBe32(payload.plugin_ssrc);
    p->audio_port = hostToBe16(payload.audio_port);
    return sizeof(ControlHeader) + sizeof(HelloPayload);
}

inline size_t encodeAck(uint8_t* out, uint32_t seq, const AckPayload& payload) {
    writeControlHeader(out, PacketType::Ack, seq, sizeof(AckPayload));
    auto* p = reinterpret_cast<AckPayload*>(out + sizeof(ControlHeader));
    p->sample_rate = hostToBe32(payload.sample_rate);
    p->engine_ssrc = hostToBe32(payload.engine_ssrc);
    return sizeof(ControlHeader) + sizeof(AckPayload);
}

inline size_t encodePingPong(uint8_t* out, PacketType type, uint32_t seq, uint64_t timestamp_us) {
    writeControlHeader(out, type, seq, sizeof(TimestampPayload));
    auto* p = reinterpret_cast<TimestampPayload*>(out + sizeof(ControlHeader));
    p->timestamp_us = hostToBe64(timestamp_us);
    return sizeof(ControlHeader) + sizeof(TimestampPayload);
}

inline size_t encodeNote(uint8_t* out, PacketType type, uint32_t seq, const NotePayload& note) {
    writeControlHeader(out, type, seq, sizeof(NotePayload));
    auto* p = reinterpret_cast<NotePayload*>(out + sizeof(ControlHeader));
    p->timestamp_us = hostToBe64(note.timestamp_us);
    p->note = note.note;
    p->velocity = note.velocity;
    return sizeof(ControlHeader) + sizeof(NotePayload);
}

inline bool decodeHello(const uint8_t* payload, HelloPayload& out) {
    HelloPayload raw{};
    std::memcpy(&raw, payload, sizeof(HelloPayload));
    out.sample_rate = beToHost32(raw.sample_rate);
    out.block_size = beToHost16(raw.block_size);
    out.plugin_ssrc = beToHost32(raw.plugin_ssrc);
    out.audio_port = beToHost16(raw.audio_port);
    return true;
}

inline bool decodeAck(const uint8_t* payload, AckPayload& out) {
    AckPayload raw{};
    std::memcpy(&raw, payload, sizeof(AckPayload));
    out.sample_rate = beToHost32(raw.sample_rate);
    out.engine_ssrc = beToHost32(raw.engine_ssrc);
    return true;
}

inline bool decodeTimestamp(const uint8_t* payload, uint64_t& timestamp_us) {
    TimestampPayload raw{};
    std::memcpy(&raw, payload, sizeof(TimestampPayload));
    timestamp_us = beToHost64(raw.timestamp_us);
    return true;
}

inline bool decodeNote(const uint8_t* payload, NotePayload& out) {
    NotePayload raw{};
    std::memcpy(&raw, payload, sizeof(NotePayload));
    out.timestamp_us = beToHost64(raw.timestamp_us);
    out.note = raw.note;
    out.velocity = raw.velocity;
    return true;
}

inline size_t encodeAudio(uint8_t* out,
                          uint32_t seq,
                          uint64_t timestamp_us,
                          uint16_t frame_count,
                          uint8_t channels,
                          const int16_t* samples) {
    auto* hdr = reinterpret_cast<AudioHeader*>(out);
    hdr->magic = hostToBe32(kMagicAudio);
    hdr->version = kVersion;
    hdr->reserved = 0;
    hdr->seq = hostToBe32(seq);
    hdr->timestamp_us = hostToBe64(timestamp_us);
    hdr->frame_count = hostToBe16(frame_count);
    hdr->channels = channels;
    hdr->pad = 0;

    const size_t sample_bytes =
        static_cast<size_t>(frame_count) * channels * sizeof(int16_t);
    std::memcpy(out + sizeof(AudioHeader), samples, sample_bytes);
    return sizeof(AudioHeader) + sample_bytes;
}

inline bool decodeAudioHeader(const uint8_t* in, size_t len, AudioHeader& hdr, size_t& payload_bytes) {
    if (len < sizeof(AudioHeader)) {
        return false;
    }
    std::memcpy(&hdr, in, sizeof(AudioHeader));
    if (beToHost32(hdr.magic) != kMagicAudio || hdr.version != kVersion) {
        return false;
    }
    hdr.seq = beToHost32(hdr.seq);
    hdr.timestamp_us = beToHost64(hdr.timestamp_us);
    hdr.frame_count = beToHost16(hdr.frame_count);
    payload_bytes = static_cast<size_t>(hdr.frame_count) * hdr.channels * sizeof(int16_t);
    return len >= sizeof(AudioHeader) + payload_bytes &&
           hdr.frame_count <= kMaxAudioFrames && hdr.channels <= kMaxAudioChannels;
}

} // namespace hdlnet
