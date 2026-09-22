# Зависимости

## Симуляция и документация

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y \
  iverilog \
  gtkwave \
  xvfb \
  python3-yaml \
  python3-jinja2 \
  python3-pil \
  python3-numpy \
  python3-matplotlib
```

Или через pip в виртуальном окружении:

```bash
pip install -r requirements.txt
```

## WavePeek (запросы к VCD, опционально)

CLI для инспекции `out.vcd` агентами и скриптами ([WavePeek](https://kleverhq.github.io/wavepeek/)). Не заменяет GTKWave для PNG.

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://kleverhq.github.io/wavepeek/install.sh | sh
wavepeek --version
```

После установки извлечь Cursor skill (версия совпадает с бинарником):

```bash
wavepeek skill .cursor/skills/wavepeek
```

Запросы через обёртку репозитория:

```bash
make sim ID=adsr
make peek ID=adsr ARGS='info'
make peek ID=adsr ARGS='scope --tree'
# или: make peek ID=adsr -- info
```

Verilator synths (`mono_synth`, `mini_fx`, `noise_box`) — offline VCD, затем тот же `make peek`:

```bash
make -C synths/noise_box TRACE=1
./synths/noise_box/obj_dir/NoiseBox \
  --dump-vcd synths/noise_box/out.vcd --dump-frames 1024 --dump-note 60
make peek ID=noise_box ARGS='info'
make peek WAVES=synths/noise_box/out.vcd ARGS='scope --tree'
```

`TRACE=1` добавляет `--trace` в Verilator. Без него `--dump-vcd` завершится ошибкой. Dump не для live UDP-сессии — только короткий offline прогон.

## Verilator realtime (отдельно)

**Legacy** (keyboard/MIDI → soundcard): [verilator_tests/README.md](../verilator_tests/README.md)

**UDP engine** (VST): [hdl-modules-tester/README.md](../hdl-modules-tester/README.md)

```bash
# legacy
sudo apt install -y verilator g++ make portaudio19-dev libasound2-dev

# UDP engine only
sudo apt install -y verilator g++ make
```
