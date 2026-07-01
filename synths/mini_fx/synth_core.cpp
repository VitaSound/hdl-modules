#include "synth_core.h"

#include "Vmini_fx.h"

namespace {
constexpr uint32_t VERILOG_CLK_HZ = 1000000;

void stepVerilogCycles(Vmini_fx* top, uint32_t cycles) {
    for (uint32_t i = 0; i < cycles; ++i) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
}

void feedMidiByte(Vmini_fx* top, uint8_t byte) {
    top->byte_in = byte;
    top->byte_valid = 1;
    stepVerilogCycles(top, 1);
    top->byte_valid = 0;
}

void drainPendingMidi(SynthCore& core) {
    for (uint8_t byte : core.pendingMidiBytes) {
        feedMidiByte(core.top, byte);
    }
    core.pendingMidiBytes.clear();
}
} // namespace

bool synthInit(SynthCore& core, uint32_t sampleRate) {
    core.top = new Vmini_fx;
    core.sampleRate = sampleRate;
    core.fractional = 0;
    core.midiDecode = {};
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();

    core.top->clk = 0;
    core.top->rst = 0;
    core.top->byte_valid = 0;
    core.top->byte_in = 0;
    core.top->audio_in_valid = 0;
    core.top->audio_in = 0;
    core.top->eval();
    return true;
}

void synthPostMidiBytes(SynthCore& core, const uint8_t* data, size_t len) {
    core.pendingMidiBytes.insert(core.pendingMidiBytes.end(), data, data + len);
}

void synthOnSessionStart(SynthCore& core) {
    drainPendingMidi(core);
    core.top->rst = 1;
    stepVerilogCycles(core.top, 4);
    core.top->rst = 0;
    core.fractional = 0;
}

void synthResetPullTiming(SynthCore& core) {
    core.fractional = 0;
}

void synthSetSampleRate(SynthCore& core, uint32_t sampleRate) {
    core.sampleRate = sampleRate;
}

uint32_t synthGetSampleRate(const SynthCore& core) {
    return core.sampleRate;
}

bool synthDrainMidiOut(SynthCore& /*core*/, std::vector<uint8_t>& /*out*/) {
    return false;
}

void synthGeneratePull(SynthCore& core,
                       const SharedState& /*state*/,
                       int16_t* mono,
                       unsigned long frames,
                       const int16_t* mono_in) {
    drainPendingMidi(core);

    for (unsigned long i = 0; i < frames; ++i) {
        const int16_t input = mono_in != nullptr ? mono_in[i] : 0;
        core.top->audio_in = input;
        core.top->audio_in_valid = 1;

        while (true) {
            core.top->clk = 0;
            core.top->eval();
            core.top->clk = 1;
            core.top->eval();
            if (core.top->audio_valid) {
                const uint16_t raw = core.top->audio_sample;
                mono[i] = static_cast<int16_t>(static_cast<int32_t>(raw) - 32768);
                break;
            }
        }
    }

    core.top->audio_in_valid = 0;
}

void synthDestroy(SynthCore& core) {
    delete core.top;
    core.top = nullptr;
    core.pendingMidiBytes.clear();
    core.midiOutBytes.clear();
}
