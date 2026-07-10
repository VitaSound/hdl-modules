# mono_synth

Моно-синт для отладки RTL «на слух»: `note_mono` + MIDI-регистры + [`mono_voice`](../../mono_voice/mono_voice.v) через UDP + VST.

**Полный справочник CC и опорных точек:** [`docs/MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md).

Wiring по образцу fpga-synth `VitaPolySimple`: gate/note из `note_mono`, A/D/R через `reg14` + `lin2exp_t`, sustain/wave через `reg7`.

## Для ИИ-агента

`synths/mono_synth/` — отдельный Verilator/UDP/VST подпроект внутри `hdl-modules`, а не модуль из основного Icarus-пайплайна `modules.yaml` → `make all`. Его цель — быстро слушать RTL-голос в DAW: MIDI из VitaSound Remote Synth приходит в engine по UDP, `top.sv` клокает RTL, C++-обвязка отдаёт PCM обратно в VST.

Текущий статус: рабочий monophonic synth engine `MonoSynth` с `mono_voice`, ADSR, waveform/PWM, pitch bend, SVF-фильтром, filter envelope, key follow и LFO/CC-схемой. Активный backlog фиксируется в [`docs/TODO.md`](../../docs/TODO.md), а MIDI/CC-контракт — в [`docs/MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md).

При разработке держать diff минимальным: RTL менять в стиле соседних `.v`, engine/VST-протокол сверять с [`hdl-modules-tester/`](../../hdl-modules-tester/) и [`vst_bridge/`](../../vst_bridge/), `obj_dir/` не коммитить. `mono_synth.params.yaml` — источник runtime-параметров для VST/CtrlrX, сгенерированную панель руками не править.

## Стек

| Слой | Что используется | Где смотреть |
|------|------------------|--------------|
| RTL top | SystemVerilog `mono_synth`, `CLK_HZ=1_000_000`, `AUDIO_HZ=44100` | `top.sv` |
| Голос | `note_mono` → `mono_voice` → DDS/ADSR/VCA/SVF/LFO | `../../mono_voice/`, `../../dds/`, `../../adsr/`, `../../svf/`, `../../lfo/` |
| MIDI/CC | `io/midi_in`, `reg7`, `reg14`, `lin2exp_t`, raw MIDI bytes | `../../io/`, `../../common/`, [`docs/MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md) |
| Verilator engine | C++ adapter, MIDI queue, session reset, PCM pull | `synth_core.cpp`, `synth_core.h`, `main.cpp` |
| UDP protocol | `hdl_net` v5: Hello/Ack, `MidiHostToEngine`, `AudioPull`, `AudioPush`, param schema | [`../../hdl-modules-tester/protocol/hdl_net.h`](../../hdl-modules-tester/protocol/hdl_net.h) |
| VST host | VitaSound Remote Synth, JUCE/VST3, runtime params from engine | [`../../vst_bridge/README.md`](../../vst_bridge/README.md) |
| Params/UI | YAML schema for APVTS and CtrlrX panel | `mono_synth.params.yaml`, `panels/mono_synth.panel`, [`docs/CTRLRX_PANEL.md`](../../docs/CTRLRX_PANEL.md) |
| Build/smoke | Verilator, `g++`, `make`, UDP smoke scripts | `Makefile`, `../../scripts/run_mono_synth.sh`, `../../scripts/e2e_mono_synth.sh` |

## Структура каталога

```text
synths/mono_synth/
  top.sv                    # Verilator top: MIDI, CC-регистры, LFO, filter env, mono_voice
  synth_core.cpp/.h          # RTL adapter: reset, MIDI feed, PCM pull
  main.cpp                   # CLI и UDP engine loop
  Makefile                   # Verilator build -> obj_dir/MonoSynth
  mono_synth.params.yaml     # machine-readable параметры для VST/CtrlrX/schema
  panels/mono_synth.panel    # generated CtrlrX panel
  svf_cutoff14_to_f.v        # 14-bit cutoff -> SVF f LUT
  svf_cc_to_q.v              # resonance CC -> SVF q LUT
  svf_cc_to_f.v              # legacy/unused helper, не в Makefile
  adsr_regs_to_ctrl4.v       # helper, не в Makefile
  obj_dir/                   # артефакт Verilator, не коммитить
```

## Текущее состояние

Сделано:

- `MonoSynth` собирается через Verilator и работает как UDP engine на `:5004`.
- MIDI notes идут через `midi_in` и `note_mono`; pitch bend передаётся в `note_pitch2dds`.
- VCA ADSR управляется CC 16–19, waveform CC 48, PWM duty CC 57.
- SVF включён внутри `mono_voice`: cutoff CC 74/106, resonance CC 71, mode CC 22.
- Filter envelope CC 24–28, key follow CC 51 и VCF-LFO3 CC 49/50/52 входят в cutoff mix.
- `mono_synth.params.yaml` описывает параметры для runtime schema VST, APVTS cache и CtrlrX panel.
- Есть smoke без DAW (`scripts/e2e_mono_synth.sh`) и E2E-сценарий через Reaper/FL Studio.

Открыто/активно по [`docs/TODO.md`](../../docs/TODO.md). Перед началом работы сверять с RTL: backlog может отставать от текущего wiring.

- Soft Hello: на reconnect того же `plugin_ssrc` не пульсировать `rst` в `synthOnSessionStart()`.
- VST Play: уменьшить количество `fullReconnect`, если UDP-соединение уже живое.
- 48 kHz vs 44.1 kHz: RTL фиксирован на `AUDIO_HZ=44100`, DAW/VST может прислать 48000.
- DDS phase sync: legato-скачок частоты сейчас без синхронизации фазы.
- VCF matrix: проверить/исправить fc 10–15 Hz в LUT и матричном тесте.
- MIDI log: `--midi-log` не печатает sys realtime `0xFC`.
- LFO -> pitch: пункт всё ещё есть в backlog; перед правкой проверить текущий путь `top.sv` → `mono_voice` → `note_pitch2dds`.

## Источники правды

| Вопрос | Документ |
|--------|----------|
| Общая архитектура repo / Icarus vs Verilator vs UDP | [`ARCHITECTURE.md`](../../ARCHITECTURE.md) |
| Правила для AI-агента и пайплайн модулей | [`AGENTS.md`](../../AGENTS.md) |
| Активные задачи и известные проблемы | [`docs/TODO.md`](../../docs/TODO.md) |
| MIDI CC, cutoff math, опорные точки | [`docs/MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md) |
| Общий паттерн `synths/*` | [`synths/README.md`](../README.md) |
| UDP engine/protocol | [`hdl-modules-tester/README.md`](../../hdl-modules-tester/README.md) |
| VST3 host | [`vst_bridge/README.md`](../../vst_bridge/README.md) |
| CtrlrX/generated panel | [`docs/CTRLRX_PANEL.md`](../../docs/CTRLRX_PANEL.md) |

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
| 57 | PWM duty 0…127 (`64` = 50%) |

### SVF-фильтр (MIDI CC)

Цепочка: **DDS @ CLK → SVF @ CLK (oversampling) → decim → VCA**. Cutoff = `manual (CC74/106)` + **key follow (CC51, pivot C4)** + **VCF-LFO3 (CC49/50/52)** + **filter env (CC24–28)** → LUT 10 Hz…20 kHz. Подробно: [`MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md).

| CC | Параметр |
|----|----------|
| 74 | Cutoff MSB → `fcut14[13:7]`; без CC106 дублируется в LSB (полный 7-bit диапазон) |
| 106 | Cutoff LSB → `fcut14[6:0]` (14-bit fine, после CC74) |
| 71 | Resonance / Q (`127 − CC`, 0 = мягко, 127 = резко) |
| 22 | Режим (старшие биты CC): **0–31**=LP, **32–63**=HP, **64–95**=BP, **96–127**=notch |
| 49 | VCF-LFO3 rate (0.1–30 Hz) |
| 50 | VCF-LFO3 depth → filter cutoff (bipolar) |
| 51 | Key follow amount 0…127 (0 = одна Hz на всех нотах; pivot **C4**) |
| 52 | VCF-LFO3 shape |

### LFO

| CC | Параметр |
|----|----------|
| 53 | VCO-LFO rate |
| 54 | VCO-LFO coarse depth → pitch |
| 55 | VCO-LFO fine depth → pitch |
| 56 | VCO-LFO shape |
| 58 | VCA-LFO2 rate |
| 59 | VCA-LFO2 depth → tremolo |
| 60 | VCA-LFO2 shape |

Пример в Reaper/FL: saw (CC 48 = 0) + длинная нота + automation CC 74/106 (sweep cutoff) при LP (CC 22 = 0).

**Sample rate:** RTL `mono_synth` — **AUDIO_HZ=44100**. В FL Studio: Settings → Audio → **44100 Hz**. Engine: `./scripts/run_mono_synth.sh` (дефолт 44100). VST Hello должен показывать `sr=44100` в логе engine.

В Reaper: piano roll → lane **MIDI CC 16** (и 17–19, 48) → нарисовать envelope перед/во время ноты. Insert → MIDI CC/OSC control item — альтернатива.

Пример: CC 16 ramp 0→127 перед длинной нотой (медленный attack); CC 19 высокое значение до note off (длинный release).

Pitch bend пересылается как обычный MIDI (status `0xE0` + 2 data bytes) в `MidiHostToEngine`.

## Архитектура

```
Reaper → VitaSound Remote Synth (VST3) ──UDP :5004/:5005──► MonoSynth (Verilator)
```

Протокол v5: [`hdl-modules-tester/protocol/hdl_net.h`](../../hdl-modules-tester/protocol/hdl_net.h) — `MidiHostToEngine` (raw bytes), `AudioPull`, `AudioPush`, runtime parameter schema из `mono_synth.params.yaml`.

## RTL

| Файл | Назначение |
|------|------------|
| `top.sv` | Top: `io/midi_in`, note_mono, reg7/reg14, mono_voice + SVF |
| `../../io/midi_in.v` | Byte FSM MIDI (без UART) |
| `svf_cutoff14_to_f.v` / `svf_cc_to_q.v` | MIDI CC → Chamberlin `f` / `q` (LUT, cutoff 10 Hz–20 kHz @ CLK 1 MHz) |
| `../../svf/svf.v` | Chamberlin SVF (внутри mono_voice при USE_SVF=1) |
| `../../common/note_mono.v` | Bitmap клавиш, highest note |
| `../../common/lin2exp_t.v` | CC → exponential rate (fpga-synth) |
