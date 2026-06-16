# Архитектура hdl-modules

Общая карта: библиотека RTL, симуляция в Icarus, реалтайм через Verilator и сетевой мост в DAW.

```mermaid
flowchart TB
  subgraph hdl_lib [HDL-модули библиотеки]
    direction TB
    common["common/<br/>powerup_reset, frqdivmod, strobe_gen"]
    gen["generation/<br/>dds, dds_transform, vca, rnd, adsr"]
  end

  subgraph icarus_pipe [Пайплайн Icarus — make test / images / docs]
    direction LR
    tb["testbench.v<br/>+ RTL .v"]
    sim["iverilog → out.vcd"]
    gtkw["test.gtkw + PNG"]
    readme["README таблица<br/>modules.yaml"]
    tb --> sim --> gtkw --> readme
  end

  subgraph verilator_rt [Verilator — Vgenerator realtime]
    direction TB
    synth["synth_core.cpp<br/>+ generator.sv"]
    veri["Verilator C++ model"]
    synth --> veri
  end

  subgraph local_mode [Локальный режим — клавиатура / MIDI / звук]
    direction TB
    kb["input_keyboard<br/>evdev q2w3er…"]
    midi_in["input_midi<br/>ALSA sequencer"]
    pa["output_soundcard<br/>PortAudio"]
    wav_out["output_wav<br/>файл .wav"]
  end

  subgraph udp_mode [Сетевой режим — DAW + VST3]
    direction TB
    daw["DAW<br/>Reaper / Bitwig"]
    vst["VitaSound Remote Synth<br/>vst_bridge VST3i"]
    udp_eng["Vgenerator --input udp<br/>input_udp + synth_core"]
    proto["hdl_net v2<br/>UDP :5004 control :5005 audio<br/>Hello / MIDI / AudioPull"]
  end

  hdl_lib -.->|"RTL в testbench<br/>и будущий синтез"| tb
  hdl_lib -.->|"пока generator.sv<br/>отдельно"| synth

  kb -->|"gate, note"| synth
  midi_in -->|"gate, note"| synth
  synth -->|"PCM"| pa
  synth -->|"PCM"| wav_out

  daw -->|"MIDI трек"| vst
  vst <-->|proto| udp_eng
  udp_eng --> synth

  readme -.-> hdl_lib
```

## Три уровня тестирования

| Уровень | Инструмент | Что проверяем | Артефакт |
|---------|------------|---------------|----------|
| **Модульный RTL** | Icarus Verilog | Один `.v` или пакет в изоляции | `test.png`, waveform в README |
| **Реалтайм на ПК** | Verilator + C++ | Тот же алгоритм под реальным clock, звук сразу | Наушники / WAV |
| **Через DAW** | VST3 + UDP engine | MIDI и PCM как в продакшене VitaSound | Reaper + `Vgenerator` |

## Локальный режим (`verilator_tests`)

```bash
cd verilator_tests && make
./obj_dir/Vgenerator                          # keyboard → soundcard
./obj_dir/Vgenerator --input midi --output wav  # MIDI → файл
```

| Ввод | Вывод | Назначение |
|------|-------|------------|
| `input_keyboard` | `output_soundcard` | Живая клавиатура PC → колонки |
| `input_midi` | `output_soundcard` / `output_wav` | MIDI-клавиатура / секвенсер |
| `input_udp` | (PCM по AudioPull) | Тот же synth, управление из VST |

Поток: **событие** (клавиша / MIDI note) → `shared_state` (`gate`, `note`) → **Verilog** `generator.sv` → **PCM** → PortAudio или WAV.

## Сетевой режим (UDP + VST)

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

Подробнее: [vst_bridge/README.md](vst_bridge/README.md), [docs/WSL_NETWORKING.md](docs/WSL_NETWORKING.md).

## Где что лежит

| Путь | Роль |
|------|------|
| `common/`, `dds/`, `vca/`, … | Исходники RTL + `*_test/` |
| `modules.yaml` | Метаданные для `make docs` |
| `tools/run_tests.py`, `make test` | Запуск Icarus по всем модулям |
| `verilator_tests/generator.sv` | Топ синтезатора для Verilator |
| `verilator_tests/input_*.cpp` | Адаптеры ввода ОС |
| `verilator_tests/output_*.cpp` | Адаптеры вывода ОС |
| `vst_bridge/` | VST3-плагин (хост в DAW) |
| `verilator_tests/protocol/hdl_net.h` | Протокол UDP (копия в `vst_bridge/protocol/`) |

## Связь с будущей ПЛИС

Библиотека `hdl-modules` — источник блоков для VitaSound FPGA. Сейчас `generator.sv` в Verilator — упрощённый MVP; модули `dds`, `adsr`, `vca` отрабатываются в Icarus и постепенно войдут в полный синтезатор на железе и в Verilator-top.
