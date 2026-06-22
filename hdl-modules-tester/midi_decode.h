#pragma once

#include <cstdint>

struct MidiDecodeState {
    uint8_t rcv_state = 0;
    uint8_t byte1 = 0;
    uint8_t byte2 = 0;
    uint8_t byte3 = 0;
};

struct MidiDecoded {
    bool ready = false;
    uint8_t ch_message = 0;
    uint8_t chan = 0;
    uint8_t lsb = 0;
    uint8_t msb = 0;
    uint8_t note = 0;
};

void midiDecodeFeed(MidiDecodeState& st, uint8_t byte, MidiDecoded& out);
