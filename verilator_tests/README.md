# verilator_tests

Реалтайм-тест Verilog-модуля генерации звука через Verilator c модульной архитектурой:

- выбираемый модуль ввода: `keyboard` (evdev) или `midi` (ALSA sequencer)
- выбираемый модуль вывода: `soundcard` (PortAudio) или `wav` (запись в файл)

## Зависимости

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y verilator g++ make portaudio19-dev libasound2-dev
```

## Сборка

```bash
cd /home/sea/hdl-modules/verilator_tests
make clean
make
```

Исполняемый файл:

```bash
./obj_dir/Vgenerator
```

## Что сделано в рефакторинге

Код разделен на отдельные модули:

- `shared_state.h` - общее состояние (`running`, `gate`, `note`)
- `synth_core.*` - шаги Verilator и генерация PCM-сэмплов
- `input_keyboard.*` - чтение `q2w3er5t6y7u` из `/dev/input/event*`
- `input_midi.*` - чтение NOTE ON/OFF из ALSA MIDI
- `output_soundcard.*` - вывод на звуковую карту через PortAudio
- `output_wav.*` - запись в WAV
- `terminal_input.*` - неблокирующее чтение `x` для выхода
- `main.cpp` - выбор модулей и оркестрация

## Как связаны ОС и Verilog

Поток данных такой:

1. Модуль ввода ОС (`input_keyboard` или `input_midi`) получает события и обновляет `shared_state`:
   - `gate` (0/1)
   - `note` (MIDI note number)
2. `synth_core.cpp` на каждом аудио-буфере подает эти данные в Verilator-модель:
   - `top->enable <= gate`
   - `top->note <= note`
3. Verilog-модуль [`generator.sv`](/home/sea/hdl-modules/verilator_tests/generator.sv) генерирует `audio_out`:
   - `case` на 12 ступеней октавы (`note % 12`)
   - делитель частоты от 1 MHz такта
4. Модуль вывода ОС:
   - `output_soundcard` отправляет PCM на звуковую карту
   - `output_wav` пишет PCM в WAV файл

То есть связка двусторонняя: ОС -> события (`gate`, `note`) -> Verilog логика -> `audio_out` -> ОС вывод.

## Параметры запуска

- `--help` - краткая справка
- `--list-devices` - показать доступные output-устройства и выйти
- `--device-index N` - выбрать устройство вывода по индексу
- `--sample-rate R` - запросить частоту дискретизации (например, `48000`)
- `--input-source keyboard|midi` - источник входа (`keyboard` по умолчанию)
- `--input-device /dev/input/eventX` - устройство клавиатуры для `evdev`-чтения
- `--list-midi` - показать доступные MIDI-порты ALSA и выйти
- `--midi-port C:P` - MIDI-порт ALSA в формате `client:port`
- `--output-mode soundcard|wav` - модуль вывода (`soundcard` по умолчанию)
- `--wav-path FILE` - путь к WAV-файлу (по умолчанию `output.wav`)
- `--wav-seconds N` - длительность WAV в секундах (по умолчанию `10`)

Если `--device-index` не указан в режиме `soundcard`, программа покажет список и попросит ввести индекс вручную.
Если `--input-source midi` и `--midi-port` не указан, программа попросит ввести `client:port`.

Примеры:

```bash
# список аудио-устройств
./obj_dir/Vgenerator --list-devices

# keyboard -> soundcard
./obj_dir/Vgenerator --device-index 9 --sample-rate 48000

# keyboard (конкретный evdev) -> soundcard
./obj_dir/Vgenerator --input-source keyboard --input-device /dev/input/event3 --device-index 9 --sample-rate 48000

# список MIDI-портов
./obj_dir/Vgenerator --input-source midi --list-midi

# midi -> soundcard
./obj_dir/Vgenerator --device-index 9 --sample-rate 48000 --input-source midi --midi-port 28:0

# keyboard -> wav
./obj_dir/Vgenerator --output-mode wav --wav-path test.wav --wav-seconds 15 --sample-rate 48000 --input-device /dev/input/event3
```

## Типовые сценарии

### 1) Keyboard -> Jabra (реалтайм)

```bash
./obj_dir/Vgenerator --input-source keyboard --input-device /dev/input/event3 --device-index 9 --sample-rate 48000
```

Примечание: `--device-index 9` это пример (часто `pulse`), уточняй через `--list-devices`.

### 2) MIDI keyboard -> Jabra (реалтайм)

Сначала найди MIDI-порт:

```bash
./obj_dir/Vgenerator --input-source midi --list-midi
```

Потом запуск (пример с портом `20:0`):

```bash
./obj_dir/Vgenerator --input-source midi --midi-port 20:0 --device-index 9 --sample-rate 48000
```

### 3) Keyboard -> WAV (без звуковой карты)

```bash
./obj_dir/Vgenerator --output-mode wav --wav-path keyboard_take.wav --wav-seconds 20 --sample-rate 48000 --input-device /dev/input/event3
```

### 4) MIDI -> WAV

```bash
./obj_dir/Vgenerator --input-source midi --midi-port 20:0 --output-mode wav --wav-path midi_take.wav --wav-seconds 20 --sample-rate 48000
```

### 5) Быстрая диагностика если нет звука

Проверь доступные аудио-устройства:

```bash
./obj_dir/Vgenerator --list-devices
```

Проверь MIDI-порты:

```bash
./obj_dir/Vgenerator --input-source midi --list-midi
```

Проверь права на evdev:

```bash
ls -l /dev/input/by-id/*-event-kbd
ls -l /dev/input/event3
id
```

## Управление клавишами

В терминале:

- `x` - выход

Через `evdev` (если доступно чтение `/dev/input/event*`):

- `q2w3er5t6y7u` - хроматическая октава C3..B3:
  - `q C3`, `2 C#3`, `w D3`, `3 D#3`, `e E3`, `r F3`, `5 F#3`, `t G3`, `6 G#3`, `y A3`, `7 A#3`, `u B3`
- `GATE` равен `1`, пока хотя бы одна из этих клавиш удерживается, и `0` после отпускания всех
- debug-лог выводит события в формате:
  - `[keyboard] GATE ON|OFF | NOTE <num> | VELOCITY 127`

Через MIDI (если выбран `--input-source midi`):

- `NOTE ON (velocity > 0)` поднимает `GATE=1`
- `NOTE OFF` (или `NOTE ON` с velocity=0) опускает `GATE`, когда зажатых MIDI-нот больше нет
- debug-лог:
  - `[midi] GATE ON|OFF | NOTE <num> | VELOCITY <real velocity>`

Сейчас в Verilog подключены и `gate`, и `note`.

## Примечания

- Запускать лучше без `sudo`, чтобы не ломать маршрут PipeWire/Pulse.
- Для `evdev` нужны права на `/dev/input/event*`. Обычно устройство имеет группу `input`, например:
```bash
ls -l /dev/input/event3
# crw-rw---- 1 root input ...
```
- Добавь пользователя в группу `input`:
```bash
sudo usermod -aG input $USER
```
- После этого обязательно обнови сессию:
```bash
newgrp input
id
```
или перелогинься/перезапусти IDE, чтобы новая группа применилась.
