#include "synth_core.h"

#include "Vmono_synth.h"

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

void clearStrobes(Vmono_synth* top) {
    top->note_on = 0;
    top->note_off = 0;
    top->cc_wr = 0;
    top->pitch_wr = 0;
    top->rst = 0;
}

void applyEvent(Vmono_synth* top, const MidiEvent& event) {
    clearStrobes(top);

    switch (event.type) {
    case MidiEventType::NoteOn:
        top->note = event.note;
        top->note_on = 1;
        stepVerilogCycles(top, 1);
        break;
    case MidiEventType::NoteOff:
        top->note = event.note;
        top->note_off = 1;
        stepVerilogCycles(top, 1);
        break;
    case MidiEventType::AllNotesOff:
        top->rst = 1;
        stepVerilogCycles(top, 1);
        break;
    case MidiEventType::ControlChange:
        top->cc_num = event.cc;
        top->cc_val = event.value;
        top->cc_wr = 1;
        stepVerilogCycles(top, 1);
        break;
    case MidiEventType::PitchBend:
        top->pitch_val = event.pitch;
        top->pitch_wr = 1;
        stepVerilogCycles(top, 1);
        break;
    }

    clearStrobes(top);
}

void drainPendingEvents(SynthCore& core) {
    for (const MidiEvent& event : core.pendingEvents) {
        applyEvent(core.top, event);
    }
    core.pendingEvents.clear();
}
} // namespace

bool synthInit(SynthCore& core, uint32_t sampleRate) {
    core.top = new Vmono_synth;
    core.sampleRate = sampleRate;
    core.fractional = 0;
    core.pendingEvents.clear();

    core.top->clk = 0;
    clearStrobes(core.top);
    core.top->note = 0;
    core.top->eval();
    return true;
}

void synthPostEvent(SynthCore& core, const MidiEvent& event) {
    core.pendingEvents.push_back(event);
}

void synthGeneratePull(SynthCore& core, const SharedState& /*state*/, int16_t* mono,
                       unsigned long frames) {
    drainPendingEvents(core);

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
    core.pendingEvents.clear();
}
