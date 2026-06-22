#include "synth_core.h"

#include "Vgenerator.h"
#include "midi_decode.h"

#include <array>

namespace {
constexpr uint32_t VERILOG_CLK_HZ = 1000000;

void stepVerilogCycles(Vgenerator* top, uint32_t cycles) {
    for (uint32_t i = 0; i < cycles; ++i) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
}

std::array<bool, 128> g_pressed{};

void applyDecodedToState(const MidiDecoded& msg, SharedState& state) {
    if (!msg.ready) {
        return;
    }

    if (msg.ch_message == 0x9) {
        if (msg.msb > 0) {
            g_pressed[msg.note] = true;
        } else {
            g_pressed[msg.note] = false;
        }
    } else if (msg.ch_message == 0x8) {
        g_pressed[msg.note] = false;
    } else if (msg.ch_message == 0xB && msg.lsb == 123) {
        g_pressed.fill(false);
    }

    bool any = false;
    int highest = -1;
    for (int n = 127; n >= 0; --n) {
        if (g_pressed[static_cast<size_t>(n)]) {
            any = true;
            highest = n;
            break;
        }
    }
    state.gate.store(any, std::memory_order_relaxed);
    state.note.store(highest, std::memory_order_relaxed);
}

void drainPendingMidi(SynthCore& core, SharedState& state) {
    MidiDecoded decoded{};
    for (uint8_t byte : core.pendingMidiBytes) {
        midiDecodeFeed(core.midiDecode, byte, decoded);
        applyDecodedToState(decoded, state);
    }
    core.pendingMidiBytes.clear();
}
} // namespace

bool synthInit(SynthCore& core, uint32_t sampleRate) {
    core.top = new Vgenerator;
    core.sampleRate = sampleRate;
    core.fractional = 0;
    core.midiDecode = {};
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();
    g_pressed.fill(false);

    core.top->clk = 0;
    core.top->enable = 0;
    core.top->note = 69;
    core.top->eval();
    return true;
}

void synthPostMidiBytes(SynthCore& core, const uint8_t* data, size_t len) {
    core.pendingMidiBytes.insert(core.pendingMidiBytes.end(), data, data + len);
}

bool synthDrainMidiOut(SynthCore& /*core*/, std::vector<uint8_t>& /*out*/) {
    return false;
}

void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames) {
    drainPendingMidi(core, const_cast<SharedState&>(state));

    core.top->enable = state.gate.load(std::memory_order_relaxed) ? 1 : 0;
    int note = state.note.load(std::memory_order_relaxed);
    if (note < 0) {
        note = 69;
    } else if (note > 127) {
        note = 127;
    }
    core.top->note = static_cast<uint8_t>(note);

    for (unsigned long i = 0; i < frames; ++i) {
        core.fractional += VERILOG_CLK_HZ;
        const uint32_t cycles = core.fractional / core.sampleRate;
        core.fractional %= core.sampleRate;
        stepVerilogCycles(core.top, cycles);

        int16_t sample = 0;
        if (core.top->enable) {
            sample = core.top->audio_out ? 12000 : -12000;
        }
        mono[i] = sample;
    }
}

void synthDestroy(SynthCore& core) {
    delete core.top;
    core.top = nullptr;
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();
}
