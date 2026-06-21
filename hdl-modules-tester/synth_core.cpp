#include "synth_core.h"

#include "Vgenerator.h"

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
} // namespace

bool synthInit(SynthCore& core, uint32_t sampleRate) {
    core.top = new Vgenerator;
    core.sampleRate = sampleRate;
    core.fractional = 0;

    core.top->clk = 0;
    core.top->enable = 0;
    core.top->note = 69;
    core.top->eval();
    return true;
}

void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames) {
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
}

void synthPostEvent(SynthCore& /*core*/, const MidiEvent& /*event*/) {}
