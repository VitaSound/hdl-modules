# hdl-modules-tester

UDP-only Verilator engine for **VitaSound Remote Synth** (VST3). HDL is clocked only on `AudioPull` from the VST host — no local soundcard, keyboard, or MIDI.

RTL: symlink [`generator.sv`](generator.sv) → [`../verilator_tests/generator.sv`](../verilator_tests/generator.sv).

Protocol: [`protocol/hdl_net.h`](protocol/hdl_net.h) (canonical copy; sync to [`../vst_bridge/protocol/`](../vst_bridge/protocol/)).

Legacy local synth (keyboard/MIDI/soundcard): [`../verilator_tests/`](../verilator_tests/).

## Dependencies

Ubuntu/Debian:

```bash
sudo apt install -y verilator g++ make
```

## Build

```bash
cd hdl-modules-tester
make clean && make
```

Binary: `obj_dir/Vgenerator`

## Run

```bash
./obj_dir/Vgenerator --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

Or from repo root: [`../scripts/run_udp_engine.sh`](../scripts/run_udp_engine.sh)

## Windows (native engine)

```bash
./scripts/build_windows_mingw.sh
```

Copy `obj_dir_win/Vgenerator.exe` to Windows; VST host `127.0.0.1`, profile **Local**.

## Smoke test

```bash
make test_hdl_net
python3 scripts/udp_smoke_test.py --duration 2
```

Full E2E: [`../scripts/e2e_ubuntu.sh`](../scripts/e2e_ubuntu.sh)

## VST bridge

See [`../vst_bridge/README.md`](../vst_bridge/README.md).
