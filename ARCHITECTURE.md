# Архитектура hdl-modules

Общая карта: библиотека RTL, симуляция в Icarus, реалтайм через Verilator и сетевой мост в DAW.

```mermaid
flowchart TB
  subgraph lib [hdl-modules — библиотека RTL]
    direction LR
    common["common/<br/>reset, dividers"]
    gen["generation/<br/>dds, vca, adsr, rnd"]
  end

  subgraph icarus [1. Icarus — make test / images / docs]
    direction LR
    tb["testbench.v + .v"]
    vcd["iverilog → VCD"]
    art["GTKWave → test.png"]
    yaml["modules.yaml → README"]
    tb --> vcd --> art --> yaml
  end

  subgraph legacy [2. verilator_tests — legacy local]
    direction TB
    kb["keyboard<br/>evdev"]
    midi["MIDI<br/>ALSA"]
    leg_eng["Vgenerator<br/>generator.sv"]
    local_out["PortAudio / WAV"]
    kb --> leg_eng
    midi --> leg_eng
    leg_eng --> local_out
  end

  subgraph network [3. hdl-modules-tester + vst_bridge — DAW]
    direction TB
    daw["DAW<br/>Reaper / Bitwig"]
    vst["VitaSound Remote Synth<br/>VST3"]
    net_eng["Vgenerator<br/>pull-only UDP"]
    proto["hdl_net v2<br/>:5004 ctrl :5005 PCM"]
    daw -->|"MIDI"| vst
    vst <-->|proto| net_eng
    vst -->|"audio"| daw
  end

  gen_rtl["generator.sv<br/>общий RTL-топ"]

  lib -.-> icarus
  lib -.->|"модули в testbench"| tb
  gen_rtl --> leg_eng
  gen_rtl --> net_eng
```

## Три уровня тестирования

| Уровень | Инструмент | Что проверяем | Артефакт |
|---------|------------|---------------|----------|
| **Модульный RTL** | Icarus Verilog | Один `.v` или пакет в изоляции | `test.png`, waveform в README |
| **Реалтайм на ПК** | Verilator + C++ (legacy) | Тот же алгоритм под реальным clock, звук сразу | Наушники / WAV |
| **Через DAW** | VST3 + UDP engine | MIDI и PCM как в продакшене VitaSound | Reaper + `Vgenerator` |

## Legacy (`verilator_tests`)

Локальный синт: клавиатура / MIDI → soundcard / WAV. Без сети.

```bash
cd verilator_tests && make
./obj_dir/Vgenerator                          # keyboard → soundcard
./obj_dir/Vgenerator --input midi --output wav  # MIDI → файл
```

| Ввод | Вывод | Назначение |
|------|-------|------------|
| `input_keyboard` | `output_soundcard` | Живая клавиатура PC → колонки |
| `input_midi` | `output_soundcard` / `output_wav` | MIDI-клавиатура / секвенсер |

Поток: **событие** (клавиша / MIDI note) → `shared_state` (`gate`, `note`) → **Verilog** `generator.sv` → **PCM** → PortAudio или WAV.

## UDP engine (`hdl-modules-tester`)

Только сеть: HDL клокается **только** на `AudioPull` от VST host.

```bash
./scripts/run_udp_engine.sh          # engine в WSL/Linux
# VST: Engine host = IP WSL или 127.0.0.1 (native engine)
```

```mermaid
sequenceDiagram
  participant DAW as DAW
  participant VST as VitaSound Remote Synth
  participant ENG as Vgenerator UDP

  DAW->>VST: MIDI notes
  VST->>ENG: Hello UDP 5004
  ENG->>VST: Ack
  loop pull v2
    VST->>ENG: AudioPull
    ENG->>VST: PCM UDP 5005
  end
  VST->>DAW: audio out
```

Подробнее: [hdl-modules-tester/README.md](hdl-modules-tester/README.md), [vst_bridge/README.md](vst_bridge/README.md), [docs/WSL_NETWORKING.md](docs/WSL_NETWORKING.md).

## Где что лежит

| Путь | Роль |
|------|------|
| `common/`, `dds/`, `vca/`, … | Исходники RTL + `*_test/` |
| `modules.yaml` | Метаданные для `make docs` |
| `tools/run_tests.py`, `make test` | Запуск Icarus по всем модулям |
| `verilator_tests/generator.sv` | Топ синтезатора для Verilator |
| `verilator_tests/` | Legacy: keyboard/MIDI → soundcard/wav |
| `hdl-modules-tester/` | UDP engine для VST (pull-only) |
| `vst_bridge/` | VST3-плагин (хост в DAW) |
| `hdl-modules-tester/protocol/hdl_net.h` | Протокол UDP (копия в `vst_bridge/protocol/`) |

## Связь с будущей ПЛИС

Библиотека `hdl-modules` — источник блоков для VitaSound FPGA. Сейчас `generator.sv` в Verilator — упрощённый MVP; модули `dds`, `adsr`, `vca` отрабатываются в Icarus и постепенно войдут в полный синтезатор на железе и в Verilator-top.
