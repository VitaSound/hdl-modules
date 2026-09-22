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

## Verilator realtime (отдельно)

**Legacy** (keyboard/MIDI → soundcard): [verilator_tests/README.md](../verilator_tests/README.md)

**UDP engine** (VST): [hdl-modules-tester/README.md](../hdl-modules-tester/README.md)

```bash
# legacy
sudo apt install -y verilator g++ make portaudio19-dev libasound2-dev

# UDP engine only
sudo apt install -y verilator g++ make
```
