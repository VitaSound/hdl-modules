# Зависимости

## Симуляция и документация

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y \
  iverilog \
  gtkwave \
  xvfb \
  ghostscript \
  python3-yaml \
  python3-jinja2
```

Или через pip в виртуальном окружении:

```bash
pip install -r requirements.txt
```

## Verilator realtime (отдельно)

См. [verilator_tests/README.md](../verilator_tests/README.md):

```bash
sudo apt install -y verilator g++ make portaudio19-dev libasound2-dev
```
