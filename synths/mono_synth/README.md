# mono_synth

Базовая полностью цифровая mono-модель звукового устройства VitaSound: `note_mono` + MIDI-регистры + [`mono_voice`](../../mono_voice/mono_voice.v) через Verilator UDP engine и VitaSound Remote Synth VST.

**Полный справочник CC и опорных точек:** [`docs/MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md).

Wiring по образцу fpga-synth `VitaPolySimple`: gate/note из `note_mono`, A/D/R через `reg14` + `lin2exp_t`, sustain/wave через `reg7`.

## Для AI-Агента

Начинать с [`docs/current-sprint.md`](docs/current-sprint.md): там текущая задача, priority, files in scope/out of scope и expected result. Перед правкой кода читать [`docs/architecture.md`](docs/architecture.md), [`docs/schema.md`](docs/schema.md), [`docs/edge-cases.md`](docs/edge-cases.md); контекст искать через [`docs/links.md`](docs/links.md), а не случайный web search.

## Документация

| Вопрос | Документ |
|--------|----------|
| Что делаем сейчас | [`docs/current-sprint.md`](docs/current-sprint.md) |
| Архитектурный подход, слои, границы | [`docs/architecture.md`](docs/architecture.md) |
| Структуры, сообщения, правила обмена | [`docs/schema.md`](docs/schema.md) |
| Не-happy-path: ошибки, пустые состояния, сбои | [`docs/edge-cases.md`](docs/edge-cases.md) |
| Где искать контекст и API | [`docs/links.md`](docs/links.md) |
| Стек, зависимости, команды | [`docs/techstack.md`](docs/techstack.md) |
| MIDI CC, cutoff math, опорные точки | [`../../docs/MONO_SYNTH_MIDI.md`](../../docs/MONO_SYNTH_MIDI.md) |
| Backlog `mono-00x` | [`../../docs/TODO.md`](../../docs/TODO.md) |

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
3. MIDI-трек → FX → **VST3: VitaSound Remote Synth** (effect; не VST3i)
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

Архитектура, RTL-связи и protocol details вынесены в [`docs/architecture.md`](docs/architecture.md) и [`docs/schema.md`](docs/schema.md).
