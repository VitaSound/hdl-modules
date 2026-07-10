# mono_synth links

Порядок поиска: `synths/mono_synth/docs/*` -> internal project links -> curated external docs -> спросить пользователя. Не искать JUCE/Verilator/MIDI с нуля в интернете, если ссылка уже есть здесь.

Цели файла:

- не тратить время на случайный поиск;
- не выдумывать API, поля protocol или CC-номера;
- быстрее находить решение в контексте проекта;
- меньше ошибаться из-за устаревших знаний модели.

## 1. Внутренние Ссылки

### mono_synth docs

| Ссылка | Когда открывать | Не путать с |
|--------|-----------------|-------------|
| [`current-sprint.md`](current-sprint.md) | В начале любой работы: что делаем сейчас | Полный backlog в `TODO.md` |
| [`architecture.md`](architecture.md) | Перед правкой кода: слой, границы, куда класть файл | Repo-wide `ARCHITECTURE.md` |
| [`schema.md`](schema.md) | Порты, поля, UDP/MIDI messages, rules of exchange | `MONO_SYNTH_MIDI.md`, где только MIDI/CC |
| [`edge-cases.md`](edge-cases.md) | Reconnect, sample rate, legato, empty states | `TODO.md`, где только задачи |
| [`techstack.md`](techstack.md) | Build/run commands, constants, tools | `docs/DEPENDENCIES.md`, где repo deps |

### Repo contracts and tasks

| Ссылка | Когда открывать | Не путать с |
|--------|-----------------|-------------|
| [`../../../docs/TODO.md`](../../../docs/TODO.md) | Backlog ids `mono-00x` | Active sprint |
| [`../../../docs/MONO_SYNTH_MIDI.md`](../../../docs/MONO_SYNTH_MIDI.md) | CC numbers, cutoff math, reference points | Runtime params YAML |
| [`../../../docs/CTRLRX_PANEL.md`](../../../docs/CTRLRX_PANEL.md) | Panel generation from params | Manual panel edits |
| [`../../../docs/WSL_NETWORKING.md`](../../../docs/WSL_NETWORKING.md) | DAW/engine connectivity through WSL | Generic UDP advice |
| [`../../../docs/LEGACY_MIGRATION_PLAN.md`](../../../docs/LEGACY_MIGRATION_PLAN.md) | Migration phases and fpga-synth references | Current sprint |
| [`../../../docs/DEPENDENCIES.md`](../../../docs/DEPENDENCIES.md) | apt/pip dependencies | Per-synth build commands |

### Code entry points

| Ссылка | Когда открывать | Не путать с |
|--------|-----------------|-------------|
| [`../top.sv`](../top.sv) | MIDI/CC wiring, registers, instantiate voice | DSP algorithm internals |
| [`../synth_core.cpp`](../synth_core.cpp) | Session reset, MIDI queue, PCM pull | UDP protocol definitions |
| [`../synth_core.h`](../synth_core.h) | Engine adapter interface | RTL ports |
| [`../main.cpp`](../main.cpp) | CLI and engine startup | Shared engine loop |
| [`../mono_synth.params.yaml`](../mono_synth.params.yaml) | New param / CC / runtime schema | RTL implementation |
| [`../Makefile`](../Makefile) | `RTL_SRCS`, build target | Repo `Makefile` |
| [`../../../hdl-modules-tester/protocol/hdl_net.h`](../../../hdl-modules-tester/protocol/hdl_net.h) | UDP wire protocol source of truth | VST copy only |
| [`../../../vst_bridge/Source/PluginProcessor.cpp`](../../../vst_bridge/Source/PluginProcessor.cpp) | VST Play/Stop/reconnect behavior | Engine session logic |
| [`../../../mono_voice/mono_voice.v`](../../../mono_voice/mono_voice.v) | Voice internals, pitch/LFO/VCA/SVF | MIDI CC mapping |
| [`../../../io/midi_in.v`](../../../io/midi_in.v) | MIDI byte parser | UART hardware |

### Neighbor projects

| Ссылка | Когда открывать | Не путать с |
|--------|-----------------|-------------|
| [`../../../hdl-modules-tester/README.md`](../../../hdl-modules-tester/README.md) | Shared UDP engine stack | `verilator_tests/` legacy local |
| [`../../../vst_bridge/README.md`](../../../vst_bridge/README.md) | VST build/run/runtime params | Engine README |
| [`../../README.md`](../../README.md) | Common `synths/*` pattern | This synth docs |
| [`../../../ARCHITECTURE.md`](../../../ARCHITECTURE.md) | Repo-wide Icarus / legacy / UDP map | `architecture.md` for mono_synth |

### Legacy reference

| Ссылка | Когда открывать | Не путать с |
|--------|-----------------|-------------|
| fpga-synth `examples/VitaPolySimple/VitaPolySimple.v` | Wiring reference for mono synth | Generated legacy LUT/MIF modules |
| [fpga-synth wiki](https://github.com/UA3MQJ/fpga-synth/wiki) | Historical ADSR/MIDI context | Current implementation contracts |

## 2. API Доки Внутри Проекта

| API / contract | Где | Когда |
|----------------|-----|-------|
| hdl_net v5 | [`schema.md`](schema.md), [`hdl_net.h`](../../../hdl-modules-tester/protocol/hdl_net.h) | Any UDP packet, session, byte-order change |
| mono_synth params | [`../mono_synth.params.yaml`](../mono_synth.params.yaml), `../../../tools/validate_synth_params.py` | New or changed CC/UI parameter |
| MIDI CC map | [`../../../docs/MONO_SYNTH_MIDI.md`](../../../docs/MONO_SYNTH_MIDI.md) | Mapping CC -> RTL registers |
| Verilator top ports | [`../top.sv`](../top.sv) | Adapter or test harness changes |
| RTL source list | [`../Makefile`](../Makefile) | New RTL dependency |

Do not invent fields in `HelloPayload`, CC numbers, UDP ports, or YAML param types. Add or change contracts in docs first, then code.

## 3. Гайдлайны Команды Проекта

| Документ | Когда |
|----------|-------|
| [`../../../AGENTS.md`](../../../AGENTS.md) | Repo style, generated README rules, artifacts not to commit |
| [`../../../docs/ADDING_MODULES.md`](../../../docs/ADDING_MODULES.md) | Adding a new library module with Icarus tests |
| [`architecture.md`](architecture.md) | `mono_synth` file-placement and ownership rules |
| [`../../../.cursor/rules/hdl-modules.mdc`](../../../.cursor/rules/hdl-modules.mdc) | Cursor short rules for this workspace |

## 4. Документация Фреймворков

Use only curated official docs unless the user asks for broader research.

| Framework | Official docs | When for mono_synth |
|-----------|---------------|---------------------|
| JUCE | https://docs.juce.com/ | VST3, APVTS, audio/MIDI handling in plugin |
| Verilator | https://verilator.org/guide/latest/ | `--cc`, warnings, generated C++ build |
| CMake | https://cmake.org/documentation/ | `vst_bridge` build system |

## 5. Официальная Документация Библиотек И Инструментов

| Tool / reference | Docs | When |
|------------------|------|------|
| Icarus Verilog | https://iverilog.fandom.com/wiki/Installation_Guide | Library modules and `make test` |
| GTKWave | Package docs / installed app help | Waveform screenshots for Icarus modules |
| MIDI Association specs | https://midi.org/specs | MIDI status bytes such as `0x8`, `0x9`, `0xB`, `0xE`, `0xFC` |
| Chamberlin SVF reference | https://www.katjaas.nl/complexintegrator/complexresonator.html | Resonance/Q theory for SVF |

## Rules For AI

1. Internal links first; web only after this file cannot answer the question.
2. If code and docs disagree, source code plus `hdl_net.h` wins; update docs in the same task.
3. Do not copy API details from memory. Open the linked file.
4. WSL/DAW/network issues start at `WSL_NETWORKING.md`, not generic Stack Overflow.
5. When changing a contract, update [`schema.md`](schema.md), [`edge-cases.md`](edge-cases.md) if behavior changes, and `TODO.md` if it affects a task id.
