# hdl-modules-tester

Общий UDP-стек (pull-mode) для Verilator synths и **VitaSound Remote Synth** (VST3). HDL тактуется только на `AudioPull` от VST — без локального soundcard/MIDI в этом каталоге.

| Engine | RTL | Назначение |
|--------|-----|------------|
| `obj_dir/Vgenerator` | [`generator.sv`](generator.sv) | MVP square-wave UDP (default) |
| [`../synths/mono_synth/`](../synths/mono_synth/) | `mono_voice` | MonoSynth + ADSR CC |
| [`../synths/noise_box/`](../synths/noise_box/) | `rndx` | NoiseBox |

Protocol: [`protocol/hdl_net.h`](protocol/hdl_net.h) — sync to [`../vst_bridge/protocol/`](../vst_bridge/protocol/).

**Legacy local** (MIDI → soundcard без DAW): [`../verilator_tests/`](../verilator_tests/) — `VgeneratorFull`.

## Protocol v3 (control :5004, audio :5005)

| Packet | Назначение |
|--------|------------|
| Hello / Ack | Сессия, sample rate |
| MidiHostToEngine | Сырые MIDI-байты 1:1 (как DIN/UART) |
| MidiEngineToHost | MIDI от engine к host (зарезервировано) |
| AudioPull | Запрос PCM от VST |

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

MonoSynth: `make -C ../synths/mono_synth`

## Run

```bash
./obj_dir/Vgenerator --udp-bind 0.0.0.0:5004 --sample-rate 48000
./scripts/run_mono_synth.sh   # from repo root
```

## Smoke test

```bash
make test_hdl_net
python3 scripts/udp_smoke_test.py --duration 2
python3 scripts/udp_smoke_test.py --duration 2 --cc-attack 0
```

E2E: [`../scripts/e2e_ubuntu.sh`](../scripts/e2e_ubuntu.sh), [`../scripts/e2e_mono_synth.sh`](../scripts/e2e_mono_synth.sh)

## VST bridge (Ubuntu 24)

```bash
cd ../vst_bridge
./scripts/install_linux_deps.sh   # libwebkit2gtk-4.1-dev on Noble
./scripts/build_linux.sh
cp -r "build/HdlVerilator_artefacts/Release/VST3/VitaSound Remote Synth.vst3" ~/.vst3/
```

Reaper: engine `127.0.0.1`, profile **Local**. См. [`../synths/mono_synth/README.md`](../synths/mono_synth/README.md).

## Windows (native engine)

```bash
./scripts/build_windows_mingw.sh
```

Copy `obj_dir_win/Vgenerator.exe` to Windows; VST host `127.0.0.1`, profile **Local**.

## VST bridge

See [`../vst_bridge/README.md`](../vst_bridge/README.md).
