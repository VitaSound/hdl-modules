#include "midi_decode.h"

namespace {
constexpr uint8_t ST_IDLE = 0;
constexpr uint8_t ST_WAIT_D1 = 1;
constexpr uint8_t ST_WAIT_D2 = 2;
constexpr uint8_t ST_SYSEX = 3;

bool isChannelStatus(uint8_t byte) {
    const uint8_t hi = byte >> 4;
    return hi >= 0x8 && hi <= 0xE && (byte & 0x80);
}
} // namespace

void midiDecodeFeed(MidiDecodeState& st, uint8_t byte, MidiDecoded& out) {
    out.ready = false;

    switch (st.rcv_state) {
    case ST_IDLE:
        if (byte == 0xF0) {
            st.rcv_state = ST_SYSEX;
        } else if (isChannelStatus(byte)) {
            st.byte1 = byte;
            st.rcv_state = ST_WAIT_D1;
        }
        break;

    case ST_WAIT_D1:
        if (!(byte & 0x80)) {
            st.byte2 = byte;
            st.rcv_state = ST_WAIT_D2;
        } else {
            st.rcv_state = ST_IDLE;
        }
        break;

    case ST_WAIT_D2:
        if (!(byte & 0x80)) {
            st.byte3 = byte;
            st.rcv_state = ST_IDLE;
            out.ready = true;
            out.ch_message = st.byte1 >> 4;
            out.chan = st.byte1 & 0x0F;
            out.lsb = st.byte2 & 0x7F;
            out.msb = st.byte3 & 0x7F;
            const uint8_t msg = out.ch_message;
            if (msg == 0x8 || msg == 0x9 || msg == 0xA) {
                out.note = out.lsb;
            } else if (msg == 0xC || msg == 0xD) {
                out.msb = 0;
            }
        } else {
            st.rcv_state = ST_IDLE;
        }
        break;

    case ST_SYSEX:
        if (byte == 0xF7) {
            st.rcv_state = ST_IDLE;
        }
        break;

    default:
        st.rcv_state = ST_IDLE;
        break;
    }
}
