#include "synth_core.h"

#include "Vmono_synth.h"

#include <iomanip>
#include <iostream>
#include <vector>

namespace {
constexpr uint32_t VERILOG_CLK_HZ = 960000;

void stepVerilogCycles(Vmono_synth* top, uint32_t cycles) {
    for (uint32_t i = 0; i < cycles; ++i) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
}

void feedMidiByte(Vmono_synth* top, uint8_t byte) {
    top->byte_in = byte;
    top->byte_valid = 1;
    stepVerilogCycles(top, 1);
    top->byte_valid = 0;
}

void logMidiDecoded(const MidiDecoded& msg) {
    if (!msg.ready) {
        return;
    }

    const int ch = static_cast<int>(msg.chan) + 1;
    switch (msg.ch_message) {
    case 0x8:
        std::cerr << "[midi] NOTE OFF ch=" << ch << " note=" << static_cast<int>(msg.note) << "\n";
        break;
    case 0x9:
        if (msg.msb > 0) {
            std::cerr << "[midi] NOTE ON ch=" << ch << " note=" << static_cast<int>(msg.note)
                      << " vel=" << static_cast<int>(msg.msb) << "\n";
        } else {
            std::cerr << "[midi] NOTE OFF ch=" << ch << " note=" << static_cast<int>(msg.note)
                      << "\n";
        }
        break;
    case 0xB:
        std::cerr << "[midi] CC ch=" << ch << " cc=" << static_cast<int>(msg.lsb)
                  << " val=" << static_cast<int>(msg.msb) << "\n";
        break;
    case 0xE: {
        const int bend = (static_cast<int>(msg.msb) << 7) | static_cast<int>(msg.lsb);
        std::cerr << "[midi] PITCH ch=" << ch << " val=" << bend << "\n";
        break;
    }
    default:
        std::cerr << "[midi] msg=0x" << std::hex << static_cast<int>(msg.ch_message) << std::dec
                  << " ch=" << ch << " d1=" << static_cast<int>(msg.lsb)
                  << " d2=" << static_cast<int>(msg.msb) << "\n";
        break;
    }
    std::cerr.flush();
}

void logMidiBytes(SynthCore& core, const uint8_t* data, size_t len) {
    std::cerr << "[midi] rx " << len << " bytes:";
    for (size_t i = 0; i < len; ++i) {
        std::cerr << ' ' << std::hex << std::setw(2) << std::setfill('0')
                  << static_cast<unsigned>(data[i]);
    }
    std::cerr << std::dec << '\n';

    MidiDecoded decoded{};
    for (size_t i = 0; i < len; ++i) {
        midiDecodeFeed(core.midiDecode, data[i], decoded);
        logMidiDecoded(decoded);
    }
    std::cerr.flush();
}

void drainPendingMidi(SynthCore& core) {
    for (uint8_t byte : core.pendingMidiBytes) {
        feedMidiByte(core.top, byte);
    }
    core.pendingMidiBytes.clear();
}
} // namespace

bool synthInit(SynthCore& core, uint32_t sampleRate) {
    core.top = new Vmono_synth;
    core.sampleRate = sampleRate;
    core.fractional = 0;
    core.midiDecode = {};
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();

    core.top->clk = 0;
    core.top->byte_valid = 0;
    core.top->byte_in = 0;
    core.top->rst = 0;
    core.top->eval();
    return true;
}

void synthPostMidiBytes(SynthCore& core, const uint8_t* data, size_t len) {
    if (core.midiLog && len > 0 && data != nullptr) {
        logMidiBytes(core, data, len);
    }
    core.pendingMidiBytes.insert(core.pendingMidiBytes.end(), data, data + len);
}

bool synthDrainMidiOut(SynthCore& core, std::vector<uint8_t>& out) {
    if (core.midiOutBytes.empty()) {
        return false;
    }
    out = std::move(core.midiOutBytes);
    core.midiOutBytes.clear();
    return true;
}

void synthGeneratePull(SynthCore& core, const SharedState& /*state*/, int16_t* mono,
                       unsigned long frames) {
    drainPendingMidi(core);

    for (unsigned long i = 0; i < frames; ++i) {
        core.fractional += VERILOG_CLK_HZ;
        const uint32_t cycles = core.fractional / core.sampleRate;
        core.fractional %= core.sampleRate;
        stepVerilogCycles(core.top, cycles);

        const uint16_t raw = core.top->audio_sample;
        mono[i] = static_cast<int16_t>(static_cast<int32_t>(raw) - 32768);
    }
}

void synthDestroy(SynthCore& core) {
    delete core.top;
    core.top = nullptr;
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();
}
