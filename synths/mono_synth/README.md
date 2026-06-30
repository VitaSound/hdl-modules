# mono_synth

Моно-синт для отладки RTL «на слух»: `note_mono` + MIDI-регистры + [`mono_voice`](../mono_voice/mono_voice.v) через UDP + VST.

**Полный справочник CC и опорных точек:** [docs/MONO_SYNTH_MIDI.md](../docs/MONO_SYNTH_MIDI.md).

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
./synths/mono_synth/obj_dir/MonoSynth --udp-bind 0.0.0.0:5004 --sample-rate 44100
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

## FL Studio / Reaper (44100 Hz)

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
2. DAW: **44100 Hz** (FL: Settings → Audio; Reaper: Project sample rate), buffer **512–1024**
3. MIDI-трек → FX → **VST3i: VitaSound Remote Synth**
4. В UI VST: **Engine host** `127.0.0.1`, **Network profile** `Local`, **Play**
5. **Test note** (C4) или ноты с piano roll / Virtual MIDI keyboard

### Проверка нот

| Способ | Действие |
|--------|----------|
| Панель VST | Play → Test note (toggle C4) |
| Piano roll | Нарисовать ноты (A4 = 69) |
| Virtual MIDI keyboard | View → Virtual MIDI keyboard |

### ADSR VCA (громкость)

| CC | Параметр |
|----|----------|
| 16 | Attack |
| 17 | Decay |
| 18 | Sustain |
| 19 | Release |

### ADSR фильтра (cutoff, независимо от VCA)

| CC | Параметр |
|----|----------|
| 24 | Filter attack |
| 25 | Filter decay |
| 26 | Filter sustain |
| 27 | Filter release |
| 28 | Filter env amount (0=выкл; аддитивно к cutoff) |

### Waveform

| CC | Параметр |
|----|----------|
| 48 | Waveform (старшие биты CC): **0–15**=saw, **16–31**=square, **32–47**=triangle, **48–63**=sine, **64–79**=ramp, **80–127**=PWM |

### SVF-фильтр (MIDI CC)

Цепочка: **DDS @ CLK → SVF @ CLK (oversampling) → decim → VCA**. Cutoff = `manual (CC74/106)` + **key follow (CC51, pivot C4)** + **LFO (CC49/50)** + **filter env (CC24–28)** → LUT 10 Hz…20 kHz. Подробно: [MONO_SYNTH_MIDI.md](../docs/MONO_SYNTH_MIDI.md).

| CC | Параметр |
|----|----------|
| 74 | Cutoff MSB → `fcut14[13:7]`; без CC106 дублируется в LSB (полный 7-bit диапазон) |
| 106 | Cutoff LSB → `fcut14[6:0]` (14-bit fine, после CC74) |
| 71 | Resonance / Q (`127 − CC`, 0 = мягко, 127 = резко) |
| 22 | Режим (старшие биты CC): **0–31**=LP, **32–63**=HP, **64–95**=BP, **96–127**=notch |
| 49 | LFO rate (0.1–30 Hz) |
| 50 | LFO depth → filter cutoff (bipolar) |
| 51 | Key follow amount 0…127 (0 = одна Hz на всех нотах; pivot **C4**) |

Пример в Reaper/FL: saw (CC 48 = 0) + длинная нота + automation CC 74/106 (sweep cutoff) при LP (CC 22 = 0).

**Sample rate:** RTL `mono_synth` — **AUDIO_HZ=44100**. В FL Studio: Settings → Audio → **44100 Hz**. Engine: `./scripts/run_mono_synth.sh` (дефолт 44100). VST Hello должен показывать `sr=44100` в логе engine.

В Reaper: piano roll → lane **MIDI CC 16** (и 17–19, 48) → нарисовать envelope перед/во время ноты. Insert → MIDI CC/OSC control item — альтернатива.

Пример: CC 16 ramp 0→127 перед длинной нотой (медленный attack); CC 19 высокое значение до note off (длинный release).

Pitch bend пересылается как обычный MIDI (status `0xE0` + 2 data bytes) в `MidiHostToEngine`.

## Архитектура

```
Reaper → VitaSound Remote Synth (VST3) ──UDP :5004/:5005──► MonoSynth (Verilator)
```

Протокол v3: [`hdl-modules-tester/protocol/hdl_net.h`](../hdl-modules-tester/protocol/hdl_net.h) — `MidiHostToEngine` (raw bytes), `AudioPull`.

## RTL

| Файл | Назначение |
|------|------------|
| `top.sv` | Top: `io/midi_in`, note_mono, reg7/reg14, mono_voice + SVF |
| `../../io/midi_in.v` | Byte FSM MIDI (без UART) |
| `svf_cutoff14_to_f.v` / `svf_cc_to_q.v` | MIDI CC → Chamberlin `f` / `q` (LUT, cutoff 10 Hz–20 kHz @ CLK 1 MHz) |
| `../../svf/svf.v` | Chamberlin SVF (внутри mono_voice при USE_SVF=1) |
| `../../common/note_mono.v` | Bitmap клавиш, highest note |
| `../../common/lin2exp_t.v` | CC → exponential rate (fpga-synth) |
