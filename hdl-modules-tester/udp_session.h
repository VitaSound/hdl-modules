#pragma once

#include "protocol/hdl_net.h"

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

struct UdpSessionState {
    std::atomic<bool> connected{false};
    std::atomic<uint32_t> sample_rate{48000};
    std::atomic<uint16_t> block_size{256};
    std::atomic<uint32_t> plugin_ssrc{0};

    mutable std::mutex plugin_mutex;
    std::string plugin_host;
    uint16_t plugin_audio_port = hdlnet::kDefaultAudioPort;
    bool has_plugin = false;

    void setPlugin(const std::string& host, uint16_t audio_port) {
        std::lock_guard<std::mutex> lock(plugin_mutex);
        plugin_host = host;
        plugin_audio_port = audio_port;
        has_plugin = true;
    }

    bool getPlugin(std::string& host, uint16_t& audio_port) const {
        std::lock_guard<std::mutex> lock(plugin_mutex);
        if (!has_plugin) {
            return false;
        }
        host = plugin_host;
        audio_port = plugin_audio_port;
        return true;
    }
};
