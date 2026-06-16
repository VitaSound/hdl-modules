# synths

Варианты синтезатора для отладки RTL «на слух» через UDP + VST.

Каждый синт — отдельный каталог:

| Каталог | Описание |
|---------|----------|
| [`noise_box/`](noise_box/) | 16-bit шум (`rndx`), gate от любой MIDI-ноты |

## Паттерн

```
synths/<name>/
  top.sv              # Verilator top
  synth_core.cpp/h    # адаптер RTL → PCM
  main.cpp            # точка входа
  Makefile            # + ../../hdl-modules-tester/{engine,net_socket}.cpp
```

Общий UDP-стек: [`hdl-modules-tester/`](../hdl-modules-tester/). VST: [`vst_bridge/`](../vst_bridge/).

На порту **5004** одновременно может работать только один engine.
