#include "synth_core.h"

#include "Vnoise_box.h"

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
} // namespace

bool synthInit(SynthCore& core, uint32_t sampleRate) {
    core.top = new Vnoise_box;
    core.sampleRate = sampleRate;
    core.fractional = 0;

    core.top->clk = 0;
    core.top->enable = 0;
    core.top->note = 0;
    core.top->eval();
    return true;
}

void synthGeneratePull(SynthCore& core, const SharedState& state, int16_t* mono, unsigned long frames) {
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
}
