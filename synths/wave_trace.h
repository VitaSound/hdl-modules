#pragma once

// Optional Verilator VCD helper for synths/* engines.
// Build with: make TRACE=1
// Offline dump: ./obj_dir/<Bin> --dump-vcd out.vcd --dump-frames 1024

#include <cstdint>
#include <iostream>
#include <string>

#ifdef VM_TRACE

#include "verilated.h"
#include "verilated_vcd_c.h"

struct WaveTrace {
    VerilatedVcdC* tfp = nullptr;
    uint64_t time = 0;
    uint64_t frames_left = 0;
    bool active = false;

    template <typename Top>
    bool open(Top* top, const std::string& path, uint64_t max_audio_frames) {
        if (max_audio_frames == 0) {
            std::cerr << "trace: max_audio_frames must be > 0\n";
            return false;
        }
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open(path.c_str());
        frames_left = max_audio_frames;
        active = true;
        time = 0;
        std::cerr << "trace: writing " << path << " for " << max_audio_frames
                  << " audio frame(s)\n";
        return true;
    }

    // Call once after a full clk low+high cycle (two evals).
    void afterCycle() {
        if (!active || tfp == nullptr) {
            return;
        }
        tfp->dump(static_cast<vluint64_t>(time));
        time += 10;
    }

    void afterAudioFrame() {
        if (!active) {
            return;
        }
        if (frames_left == 0) {
            return;
        }
        --frames_left;
        if (frames_left == 0) {
            close();
        }
    }

    void close() {
        if (tfp != nullptr) {
            tfp->flush();
            tfp->close();
            delete tfp;
            tfp = nullptr;
        }
        active = false;
        frames_left = 0;
    }
};

#else

struct WaveTrace {
    template <typename Top>
    bool open(Top*, const std::string&, uint64_t) {
        std::cerr << "trace: binary built without TRACE=1\n";
        return false;
    }
    void afterCycle() {}
    void afterAudioFrame() {}
    void close() {}
    bool active = false;
};

#endif
