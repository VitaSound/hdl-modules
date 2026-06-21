# mono_synth

Моно-синт для отладки RTL «на слух»: `note_mono` + MIDI-регистры (ADSR CC 16–19, wave CC 48) + [`mono_voice`](../mono_voice/mono_voice.v) через UDP + VST.

Wiring по образцу fpga-synth `VitaPolySimple`: gate/note из `note_mono`, A/D/R через `reg14` + `lin2exp_t`, sustain/wave через `reg7`.

## Сборка

```bash
sudo apt install -y verilator g++ make
make -C synths/mono_synth
```

Бинарник: `synths/mono_synth/obj_dir/MonoSynth`

## Запуск engine

```bash
./scripts/run_mono_synth.sh
# или вручную:
./synths/mono_synth/obj_dir/MonoSynth --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

На порту **5004** одновременно может работать только один UDP engine.

## Smoke без DAW (Ubuntu)

```bash
./scripts/e2e_mono_synth.sh
# WAV: /tmp/mono_synth_e2e.wav
```

Или вручную:

```bash
./synths/mono_synth/obj_dir/MonoSynth &
python3 hdl-modules-tester/scripts/udp_smoke_test.py --duration 3 --cc-attack 0
```

## Reaper на Ubuntu 24

### Зависимости (один раз)

```bash
sudo apt install -y verilator g++ make

cd vst_bridge
./scripts/install_linux_deps.sh
./scripts/build_linux.sh
cp -r "build/HdlVerilator_artefacts/Release/VST3/VitaSound Remote Synth.vst3" ~/.vst3/
```

Reaper: [reaper.fm/download.php](https://www.reaper.fm/download.php) (Linux x86_64). После копирования VST — rescan plugins.

### E2E в DAW

1. Терминал: `./scripts/run_mono_synth.sh`
2. Reaper: новый проект, **Project sample rate 48000 Hz**, buffer **512–1024**
3. MIDI-трек → FX → **VST3i: VitaSound Remote Synth**
4. В UI VST: **Engine host** `127.0.0.1`, **Network profile** `Local`, **Play**
5. **Test note** (C4) или ноты с piano roll / Virtual MIDI keyboard

### Проверка нот

| Способ | Действие |
|--------|----------|
| Панель VST | Play → Test note (toggle C4) |
| Piano roll | Нарисовать ноты (A4 = 69) |
| Virtual MIDI keyboard | View → Virtual MIDI keyboard |

### ADSR и waveform (MIDI CC)

| CC | Параметр |
|----|----------|
| 16 | Attack |
| 17 | Decay |
| 18 | Sustain |
| 19 | Release |
| 48 | Waveform: 0=saw, 1=square, 2=triangle, 3=sine, 4=ramp, 5=PWM |

В Reaper: piano roll → lane **MIDI CC 16** (и 17–19, 48) → нарисовать envelope перед/во время ноты. Insert → MIDI CC/OSC control item — альтернатива.

Пример: CC 16 ramp 0→127 перед длинной нотой (медленный attack); CC 19 высокое значение до note off (длинный release).

Pitch bend поддерживается через UDP `PitchBend` (VST пересылает wheel из DAW).

## Архитектура

```
Reaper → VitaSound Remote Synth (VST3) ──UDP :5004/:5005──► MonoSynth (Verilator)
```

Протокол: [`hdl-modules-tester/protocol/hdl_net.h`](../hdl-modules-tester/protocol/hdl_net.h) — `NoteOn/Off`, `ControlChange`, `PitchBend`, `AudioPull`.

## RTL

| Файл | Назначение |
|------|------------|
| `top.sv` | Top: note_mono, reg7/reg14, mono_voice |
| `adsr_regs_to_ctrl4.v` | 14-bit ADSR regs → 4-bit mono_voice |
| `../../common/note_mono.v` | Bitmap клавиш, highest note |
| `../../common/lin2exp_t.v` | CC → exponential rate (fpga-synth) |
