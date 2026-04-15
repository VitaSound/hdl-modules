# verilator_tests

Реалтайм-тест Verilog-модуля генерации звука через Verilator + PortAudio.

## Зависимости

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y verilator g++ make portaudio19-dev
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

## Параметры запуска

- `--list-devices` - показать доступные output-устройства и выйти
- `--device-index N` - выбрать устройство вывода по индексу
- `--sample-rate R` - запросить частоту дискретизации (например, `48000`)
- `--input-device /dev/input/eventX` - устройство клавиатуры для `evdev`-чтения

Если `--device-index` не указан, программа покажет список и попросит ввести индекс вручную.

Примеры:

```bash
./obj_dir/Vgenerator --list-devices
./obj_dir/Vgenerator --device-index 9 --sample-rate 48000
./obj_dir/Vgenerator --device-index 4 --sample-rate 44100 --input-device /dev/input/event2
```

## Управление клавишами

В терминале:

- `x` - выход
- `1` - `toggle` on/off
- `t` - `force tone` on/off (диагностический режим, звук принудительно)
- `space` - `gate` off (терминальный gate)
- `q w e r t y u` - установка `note` и `gate=on` (fallback из терминала)

Через `evdev` (если доступно чтение `/dev/input/event*`):

- `1` - `toggle` on/off
- `q w e r t y u` - первая октава: обновляют `note`, поднимают `gate` на нажатии и опускают на отпускании

Сейчас в Verilog подключен только `gate` (с учетом `toggle`/`force tone`), переменная `note` сохраняется в программе и будет подключена позже.

## Примечания

- Запускать лучше без `sudo`, чтобы не ломать маршрут PipeWire/Pulse.
- Если используешь `evdev`, могут понадобиться права на `/dev/input/event*` (группа `input` или правила доступа).
