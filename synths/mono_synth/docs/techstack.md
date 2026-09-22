# mono_synth tech stack

Этот файл отвечает на вопрос «чем это собрано и как запускать». Архитектурные границы — в [`architecture.md`](architecture.md), форматы обмена — в [`schema.md`](schema.md).

## Summary

| Layer | Tech | Main files |
|-------|------|------------|
| RTL top | SystemVerilog / Verilog | `../top.sv`, local LUT `.v` |
| RTL library | Verilog modules from repo root | `../../../mono_voice/`, `../../../dds/`, `../../../adsr/`, `../../../svf/`, `../../../lfo/`, `../../../vca/`, `../../../common/`, `../../../io/` |
| Simulation / build | Verilator `--cc --exe` + `g++` | `../Makefile` |
| Engine | C++ adapter and shared UDP loop | `../synth_core.cpp`, `../main.cpp`, `../../../hdl-modules-tester/` |
| Protocol | `hdl_net` v5 UDP | `../../../hdl-modules-tester/protocol/hdl_net.h` |
| Host | JUCE VST3 | `../../../vst_bridge/` |
| Params | YAML runtime schema | `../mono_synth.params.yaml` |
| Smoke | Python UDP client / shell scripts | `../../../scripts/e2e_mono_synth.sh`, `../../../hdl-modules-tester/scripts/udp_smoke_test.py` |

## Constants

| Name | Value | Source |
|------|-------|--------|
| RTL clock | `CLK_HZ = 1_000_000` | `../top.sv` |
| RTL sample rate | `AUDIO_HZ = 44100` | `../top.sv` |
| Legacy ADSR rate scale | `LEGACY_ADSR_CLK_HZ = 50_000_000` | `../top.sv` |
| UDP control port | `5004` | `hdl_net.h` default |
| UDP audio port | `5005` | `hdl_net.h` default |
| Protocol version | `5` | `hdl_net.h` |
| Max MIDI payload | `1024` bytes | `hdl_net.h` |
| Max audio packet frames | `256` | `hdl_net.h` |
| Default max frames per pull | `2048` | `hdl_net.h` |

## Build Dependencies

Ubuntu/Debian for this engine:

```bash
sudo apt install -y verilator g++ make
```

Repo-wide simulation/docs dependencies are listed in [`../../../docs/DEPENDENCIES.md`](../../../docs/DEPENDENCIES.md).

VST build dependencies are handled by [`../../../vst_bridge/scripts/install_linux_deps.sh`](../../../vst_bridge/scripts/install_linux_deps.sh) and described in [`../../../vst_bridge/README.md`](../../../vst_bridge/README.md).

## Build Commands

From repo root:

```bash
make -C synths/mono_synth
make -C synths/mono_synth TRACE=1   # VCD dump support for WavePeek
```

Output binary:

```text
synths/mono_synth/obj_dir/MonoSynth
```

Offline WavePeek dump (no UDP):

```bash
./synths/mono_synth/obj_dir/MonoSynth \
  --dump-vcd synths/mono_synth/out.vcd --dump-frames 1024 --dump-note 60
make peek ID=mono_synth ARGS='info'
```

Clean:

```bash
make -C synths/mono_synth clean
```

## Runtime Commands

Run engine:

```bash
./scripts/run_mono_synth.sh
```

Manual run:

```bash
./synths/mono_synth/obj_dir/MonoSynth --udp-bind 0.0.0.0:5004 --sample-rate 44100
```

Smoke without DAW:

```bash
./scripts/e2e_mono_synth.sh
```

Manual UDP smoke:

```bash
./synths/mono_synth/obj_dir/MonoSynth &
python3 hdl-modules-tester/scripts/udp_smoke_test.py --duration 3 --cc-attack 0
```

## VST / DAW

Build Linux VST:

```bash
cd vst_bridge
./scripts/install_linux_deps.sh
./scripts/build_linux.sh
cp -r "build/HdlVerilator_artefacts/Release/VST3/VitaSound Remote Synth.vst3" ~/.vst3/
```

DAW settings for current RTL:

- sample rate: `44100`
- buffer: `512` to `1024`
- engine host: `127.0.0.1` for native/Linux local engine
- network profile: `Local`

Networking and WSL notes: [`../../../docs/WSL_NETWORKING.md`](../../../docs/WSL_NETWORKING.md).

## Makefile Inputs

`../Makefile` has two source lists:

- `RTL_SRCS`: `top.sv`, library Verilog modules, local SVF LUTs.
- `CPP_SRCS`: `synth_core.cpp`, `main.cpp`, shared `hdl-modules-tester` engine/socket/MIDI decode files.

If a new RTL file is required by `top.sv`, add it to `RTL_SRCS`. If it is reusable beyond `mono_synth`, put it in a library package and add Icarus coverage per [`../../../docs/ADDING_MODULES.md`](../../../docs/ADDING_MODULES.md).

## What This Is Not

- Not part of `modules.yaml`.
- Not part of repo `make all`.
- Not an Icarus waveform/README package.
- Not `verilator_tests/` legacy local audio path.
- Not `mini_fx` AudioPush path.

Use `make docs` only for generated library README files. `synths/mono_synth/README.md` and files in this directory are hand-written docs.
