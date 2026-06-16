# verilator_tests (legacy)

Локальный реалтайм-тест Verilog-модуля генерации звука через Verilator:

- ввод: `keyboard` (evdev) или `midi` (ALSA sequencer)
- вывод: `soundcard` (PortAudio) или `wav` (запись в файл)

**UDP engine для VST:** [`../hdl-modules-tester/`](../hdl-modules-tester/) — отдельный проект, только сеть.

## Зависимости

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y verilator g++ make portaudio19-dev libasound2-dev
```

## Сборка

```bash
cd verilator_tests
make clean && make
```

Исполняемый файл: `obj_dir/Vgenerator`

## Запуск

```bash
./obj_dir/Vgenerator
```

По умолчанию: keyboard → soundcard.

### Примеры

```bash
./obj_dir/Vgenerator --list-devices
./obj_dir/Vgenerator --device-index 9 --sample-rate 48000
./obj_dir/Vgenerator --input-source keyboard --input-device /dev/input/event3 --device-index 9 --sample-rate 48000
./obj_dir/Vgenerator --input-source midi --list-midi
./obj_dir/Vgenerator --input-source midi --midi-port 28:0 --device-index 9 --sample-rate 48000
./obj_dir/Vgenerator --output-mode wav --wav-path test.wav --wav-seconds 15 --sample-rate 48000 --input-device /dev/input/event3
```

Нажмите `[x]` в терминале для выхода.

## Модули

| Файл | Роль |
|------|------|
| `shared_state.h` | `running`, `gate`, `note` |
| `synth_core.*` | шаги Verilator и генерация PCM |
| `input_keyboard.*` | evdev `q2w3er5t6y7u` |
| `input_midi.*` | ALSA MIDI NOTE ON/OFF |
| `output_soundcard.*` | PortAudio callback |
| `output_wav.*` | запись WAV |
| `generator.sv` | топ синтезатора |

## VST / DAW

См. [`../hdl-modules-tester/README.md`](../hdl-modules-tester/README.md) и [`../vst_bridge/README.md`](../vst_bridge/README.md).
