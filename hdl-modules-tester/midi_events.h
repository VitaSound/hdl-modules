#pragma once

#include <cstdint>

enum class MidiEventType : uint8_t {
    NoteOn = 0,
    NoteOff = 1,
    AllNotesOff = 2,
    ControlChange = 3,
    PitchBend = 4,
};

struct MidiEvent {
    MidiEventType type = MidiEventType::NoteOn;
    uint8_t note = 0;
    uint8_t velocity = 0;
    uint8_t cc = 0;
    uint8_t value = 0;
    uint16_t pitch = 8192;
};

struct SynthCore;

void synthPostEvent(SynthCore& core, const MidiEvent& event);
