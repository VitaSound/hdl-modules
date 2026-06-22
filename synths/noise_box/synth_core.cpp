#include "synth_core.h"

#include "Vnoise_box.h"
#include "midi_decode.h"

#include <array>

namespace {
constexpr uint32_t VERILOG_CLK_HZ = 1000000;

void stepVerilogCycles(Vnoise_box* top, uint32_t cycles) {
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
    for (bool v : g_pressed) {
        if (v) {
            any = true;
            break;
        }
    }
    state.gate.store(any, std::memory_order_relaxed);
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
    core.top = new Vnoise_box;
    core.sampleRate = sampleRate;
    core.fractional = 0;
    core.midiDecode = {};
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();
    g_pressed.fill(false);

    core.top->clk = 0;
    core.top->enable = 0;
    core.top->note = 0;
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

    for (unsigned long i = 0; i < frames; ++i) {
        core.fractional += VERILOG_CLK_HZ;
        const uint32_t cycles = core.fractional / core.sampleRate;
        core.fractional %= core.sampleRate;
        stepVerilogCycles(core.top, cycles);

        int16_t sample = 0;
        if (core.top->enable) {
            const uint16_t raw = core.top->audio_sample;
            sample = static_cast<int16_t>(static_cast<int32_t>(raw) - 32768);
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
