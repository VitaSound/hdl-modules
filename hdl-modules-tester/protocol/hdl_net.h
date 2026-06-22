#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace hdlnet {

constexpr uint32_t kMagicControl = 0x48444C4Du; // "HDLM"
constexpr uint32_t kMagicAudio = 0x48444C41u;   // "HDLA"
constexpr uint8_t kVersion = 3;

constexpr uint16_t kDefaultControlPort = 5004;
constexpr uint16_t kDefaultAudioPort = 5005;

constexpr uint16_t kMaxAudioFrames = 256;
constexpr uint16_t kMaxAudioChannels = 2;
constexpr size_t kAudioHeaderSize = 22;
constexpr size_t kMaxAudioPacketBytes =
    kAudioHeaderSize + kMaxAudioFrames * kMaxAudioChannels * sizeof(int16_t);

constexpr uint16_t kMaxMidiBytes = 1024;
constexpr size_t kMidiHeaderPayloadSize = sizeof(uint64_t) + sizeof(uint16_t);

constexpr uint8_t kSessionModePull = 1;
constexpr uint16_t kDefaultMaxFramesPerPull = 2048;

constexpr uint16_t kCapAudioPush = 0x0001;

enum class PacketType : uint8_t {
    Hello = 1,
    Ack = 2,
    Ping = 3,
    Pong = 4,
    MidiHostToEngine = 5,
    MidiEngineToHost = 6,
    AudioPull = 8,
    AudioPush = 9,
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
    uint8_t session_mode;
    uint8_t reserved;
    uint16_t packet_frames;
    uint16_t initial_warmup_packets;
    uint16_t min_reserve_packets;
    uint16_t target_reserve_packets;
};

struct AckPayload {
    uint32_t sample_rate;
    uint32_t engine_ssrc;
    uint16_t packet_frames;
    uint16_t max_frames_per_pull;
    uint16_t caps;
    uint16_t reserved;
};

struct AudioPullPayload {
    uint32_t request_id;
    uint32_t frame_count;
    uint32_t host_fill;
    uint32_t host_target;
};

struct TimestampPayload {
    uint64_t timestamp_us;
};

struct MidiPayloadHeader {
    uint64_t timestamp_us;
    uint16_t length;
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
    p->session_mode = payload.session_mode;
    p->reserved = 0;
    p->packet_frames = hostToBe16(payload.packet_frames);
    p->initial_warmup_packets = hostToBe16(payload.initial_warmup_packets);
    p->min_reserve_packets = hostToBe16(payload.min_reserve_packets);
    p->target_reserve_packets = hostToBe16(payload.target_reserve_packets);
    return sizeof(ControlHeader) + sizeof(HelloPayload);
}

inline size_t encodeAck(uint8_t* out, uint32_t seq, const AckPayload& payload) {
    writeControlHeader(out, PacketType::Ack, seq, sizeof(AckPayload));
    auto* p = reinterpret_cast<AckPayload*>(out + sizeof(ControlHeader));
    p->sample_rate = hostToBe32(payload.sample_rate);
    p->engine_ssrc = hostToBe32(payload.engine_ssrc);
    p->packet_frames = hostToBe16(payload.packet_frames);
    p->max_frames_per_pull = hostToBe16(payload.max_frames_per_pull);
    p->caps = hostToBe16(payload.caps);
    p->reserved = hostToBe16(payload.reserved);
    return sizeof(ControlHeader) + sizeof(AckPayload);
}

inline size_t encodeAudioPull(uint8_t* out, uint32_t seq, const AudioPullPayload& payload) {
    writeControlHeader(out, PacketType::AudioPull, seq, sizeof(AudioPullPayload));
    auto* p = reinterpret_cast<AudioPullPayload*>(out + sizeof(ControlHeader));
    p->request_id = hostToBe32(payload.request_id);
    p->frame_count = hostToBe32(payload.frame_count);
    p->host_fill = hostToBe32(payload.host_fill);
    p->host_target = hostToBe32(payload.host_target);
    return sizeof(ControlHeader) + sizeof(AudioPullPayload);
}

inline size_t encodePingPong(uint8_t* out, PacketType type, uint32_t seq, uint64_t timestamp_us) {
    writeControlHeader(out, type, seq, sizeof(TimestampPayload));
    auto* p = reinterpret_cast<TimestampPayload*>(out + sizeof(ControlHeader));
    p->timestamp_us = hostToBe64(timestamp_us);
    return sizeof(ControlHeader) + sizeof(TimestampPayload);
}

inline size_t encodeMidi(uint8_t* out,
                         PacketType type,
                         uint32_t seq,
                         uint64_t timestamp_us,
                         const uint8_t* data,
                         uint16_t length) {
    const uint16_t payload_len = static_cast<uint16_t>(kMidiHeaderPayloadSize + length);
    writeControlHeader(out, type, seq, payload_len);
    auto* hdr = reinterpret_cast<MidiPayloadHeader*>(out + sizeof(ControlHeader));
    hdr->timestamp_us = hostToBe64(timestamp_us);
    hdr->length = hostToBe16(length);
    if (length > 0 && data != nullptr) {
        std::memcpy(out + sizeof(ControlHeader) + kMidiHeaderPayloadSize, data, length);
    }
    return sizeof(ControlHeader) + payload_len;
}

inline bool decodeMidi(const uint8_t* payload,
                       size_t payload_len,
                       uint64_t& timestamp_us,
                       const uint8_t*& data,
                       uint16_t& length) {
    if (payload_len < kMidiHeaderPayloadSize) {
        return false;
    }
    MidiPayloadHeader raw{};
    std::memcpy(&raw, payload, sizeof(MidiPayloadHeader));
    timestamp_us = beToHost64(raw.timestamp_us);
    length = beToHost16(raw.length);
    if (length > kMaxMidiBytes || payload_len < kMidiHeaderPayloadSize + length) {
        return false;
    }
    data = payload + kMidiHeaderPayloadSize;
    return true;
}

inline bool decodeHello(const uint8_t* payload, HelloPayload& out) {
    HelloPayload raw{};
    std::memcpy(&raw, payload, sizeof(HelloPayload));
    out.sample_rate = beToHost32(raw.sample_rate);
    out.block_size = beToHost16(raw.block_size);
    out.plugin_ssrc = beToHost32(raw.plugin_ssrc);
    out.audio_port = beToHost16(raw.audio_port);
    out.session_mode = raw.session_mode;
    out.reserved = raw.reserved;
    out.packet_frames = beToHost16(raw.packet_frames);
    out.initial_warmup_packets = beToHost16(raw.initial_warmup_packets);
    out.min_reserve_packets = beToHost16(raw.min_reserve_packets);
    out.target_reserve_packets = beToHost16(raw.target_reserve_packets);
    return true;
}

inline bool decodeAck(const uint8_t* payload, AckPayload& out) {
    AckPayload raw{};
    std::memcpy(&raw, payload, sizeof(AckPayload));
    out.sample_rate = beToHost32(raw.sample_rate);
    out.engine_ssrc = beToHost32(raw.engine_ssrc);
    out.packet_frames = beToHost16(raw.packet_frames);
    out.max_frames_per_pull = beToHost16(raw.max_frames_per_pull);
    out.caps = beToHost16(raw.caps);
    out.reserved = beToHost16(raw.reserved);
    return true;
}

inline bool decodeAudioPull(const uint8_t* payload, AudioPullPayload& out) {
    AudioPullPayload raw{};
    std::memcpy(&raw, payload, sizeof(AudioPullPayload));
    out.request_id = beToHost32(raw.request_id);
    out.frame_count = beToHost32(raw.frame_count);
    out.host_fill = beToHost32(raw.host_fill);
    out.host_target = beToHost32(raw.host_target);
    return true;
}

inline bool decodeTimestamp(const uint8_t* payload, uint64_t& timestamp_us) {
    TimestampPayload raw{};
    std::memcpy(&raw, payload, sizeof(TimestampPayload));
    timestamp_us = beToHost64(raw.timestamp_us);
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
