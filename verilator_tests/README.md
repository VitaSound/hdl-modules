# verilator_tests (legacy)

Локальный реалтайм-тест Verilog-модуля генерации звука через Verilator:

- ввод: `keyboard` (evdev) или `midi` (ALSA sequencer)
- вывод: `soundcard` (PortAudio) или `wav` (запись в файл)

**UDP engine для VST:** [`../hdl-modules-tester/`](../hdl-modules-tester/) + [`../synths/mono_synth/`](../synths/mono_synth/) — отдельные проекты, только сеть.

## Зависимости

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y verilator g++ make portaudio19-dev libasound2-dev
```

## Сборка

```bash
cd verilator_tests
make clean && make        # Vgenerator (legacy, одна октава)
make full                 # VgeneratorFull (полный MIDI 0..127)
```

| Бинарник | RTL | Ноты |
|----------|-----|------|
| `obj_dir/Vgenerator` | `generator.sv` | одна октава (`note % 12`, совместимость) |
| `obj_dir/VgeneratorFull` | `generator_fullrange.sv` | полный MIDI 0..127, A4=440 Hz |

Если `make full` пишет *Nothing to be done* — бинарник уже собран; запускай `./obj_dir/VgeneratorFull` или `make clean && make full`.

## Запуск

По умолчанию `Vgenerator`: keyboard → soundcard.

### MIDI-клавиатура (рекомендуется для AXELVOX и др.)

```bash
./obj_dir/VgeneratorFull --input-source midi --list-midi
./obj_dir/VgeneratorFull --input-source midi --midi-port 32:0 --device-index 3 --sample-rate 48000
```

1. `--list-midi` — найти `client:port` (например `32:0 | AXELVOX KEY49J`).
2. `--list-devices` — индекс выхода (на Ubuntu часто `pipewire` / `pulse` / `default`).
3. Выход: **`[x]`** в терминале или Ctrl+C.

### Поведение MIDI (`input_midi.cpp`)

| Событие | Поведение |
|---------|-----------|
| Note On / Off | Номер ноты **без переназначения** (0..127) |
| Несколько клавиш | **Highest note** — звучит самая высокая зажатая |
| Pitch wheel | **Не поддерживается** (нет в legacy) |
| MIDI CC (ADSR) | **Не поддерживается** |

Для pitch bend и ADSR CC → [`../synths/mono_synth/`](../synths/mono_synth/) + VST или будущая доработка legacy.

### Прочие примеры

```bash
./obj_dir/Vgenerator --list-devices
./obj_dir/Vgenerator --input-source keyboard --input-device /dev/input/event3 --device-index 9
./obj_dir/Vgenerator --output-mode wav --wav-path test.wav --wav-seconds 15
```

Клавиатура PC (`keyboard`): только октава `q2w3er5t6y7u` → ноты 48..59.

## Модули

| Файл | Роль |
|------|------|
| `shared_state.h` | `running`, `gate`, `note` |
| `generator.sv` | MVP-квадрат, `note % 12` |
| `generator_fullrange.sv` | Квадрат, полный MIDI-диапазон |
| `synth_core*.cpp/h` | Шаги Verilator → PCM |
| `input_keyboard.*` | evdev, одна октава |
| `input_midi.*` | ALSA Note On/Off |
| `output_soundcard.*` | PortAudio |
| `output_wav.*` | WAV |

## VST / DAW

См. [`../synths/mono_synth/README.md`](../synths/mono_synth/README.md), [`../hdl-modules-tester/README.md`](../hdl-modules-tester/README.md), [`../vst_bridge/README.md`](../vst_bridge/README.md).
