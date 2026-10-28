# fsoc and later growth

hdl-modules is the Verilog library consumed by [fsoc](https://github.com/VitaSound/fsoc), the Forth-native SoC builder.

## Stage 4 (first MIT vertical slice)

DIN MIDI foot controller:

- `common/debounce` — GPIO events
- `io/uart_tx` — 31250 baud MIDI OUT
- J1 firmware `FOOTSWITCH-SCAN` lives in fsoc (`firmware/midi_foot.4th`)

## Stage 5+

- Drive existing audio cores (`mono_voice`, `midi_in`, I2S/DAC) through CSR
- Keep one `.v` per module; fsoc instantiates, it does not flatten
- Expression trees and Forth-side sim stay in fhdlgen; board import and yosys/nextpnr stay in fsoc
