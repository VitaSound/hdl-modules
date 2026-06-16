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
  python3-pil
```

Или через pip в виртуальном окружении:

```bash
pip install -r requirements.txt
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
