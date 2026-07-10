# mono_synth architecture

Перед изменением кода определить **слой**, **затронутые модули**, **контракт** (MIDI CC / UDP / RTL ports) и **уровень проверки**. Не добавлять логику в `top.sv`, если она относится к переиспользуемому блоку библиотеки.

`mono_synth` нельзя дорабатывать как отдельный мини-проект. Это интеграционный top над библиотекой `hdl-modules`, UDP engine и VST-мостом; любое изменение должно сохранять контракты соседних слоёв.

## Архитектурный Подход

`mono_synth` — базовая полностью цифровая mono-модель звукового устройства VitaSound. На основе таких моделей должны строиться следующие синтезаторы и устройства платформы: `mono_synth` закрывает нишу моно-голоса, `mini_fx` — обработку входного аудио, `noise_box` — минимальный первый UDP/VST engine.

Цепочка ценности:

```text
RTL-библиотека -> Verilator engine -> VitaSound Remote Synth VST -> будущая ПЛИС
```

Роль `synths/mono_synth/top.sv` — связать MIDI/CC, регистры, LFO, filter envelope и `mono_voice`. DSP-алгоритмы живут в библиотечных блоках (`mono_voice/`, `dds/`, `adsr/`, `svf/`, `lfo/`, `vca/`), а не в C++ engine и не в VST.

Референс wiring — fpga-synth `VitaPolySimple`. Копировать legacy-generated `note2dds_*`, `.mif` и пакетные копии из `examples/*/modules/` не нужно; актуальная реализация живёт в `hdl-modules`.

Подход к проверке: Verilator-first для интеграционного поведения `mono_synth`. Icarus нужен для новых или изменённых переиспользуемых `.v`, когда изолированный контракт блока нельзя надёжно проверить через Verilator top.

## Основные Слои Системы

| Слой | Ответственность | Ключевые пути |
|------|-----------------|---------------|
| Library RTL | Переиспользуемые синтезаторные блоки | `../../../common/`, `../../../dds/`, `../../../mono_voice/`, `../../../svf/`, `../../../lfo/`, `../../../adsr/`, `../../../vca/`, `../../../io/` |
| Integration RTL | MIDI/CC wiring, локальные LUT, связывание голоса | `../top.sv`, `../svf_cutoff14_to_f.v`, `../svf_cc_to_q.v` |
| Engine adapter | Verilator ↔ MIDI queue ↔ PCM pull | `../synth_core.cpp`, `../synth_core.h`, `../main.cpp` |
| Shared network | UDP protocol, socket, engine loop | `../../../hdl-modules-tester/` |
| VST host | DAW bridge, UI, APVTS, reconnect | `../../../vst_bridge/` |
| Params contract | Имена параметров, CC, runtime schema | `../mono_synth.params.yaml`, `../panels/mono_synth.panel` |

Детали инструментов и команд сборки вынесены в [`techstack.md`](techstack.md). Форматы сообщений и полей — в [`schema.md`](schema.md).

## Структура Папок

```text
synths/mono_synth/
  top.sv                    # Verilator top: MIDI, CC regs, LFO, filter env, mono_voice
  synth_core.cpp/.h          # RTL adapter: reset, MIDI feed, PCM pull
  main.cpp                   # CLI and UDP engine loop
  Makefile                   # Verilator build -> obj_dir/MonoSynth
  mono_synth.params.yaml     # runtime params for VST/CtrlrX/schema
  panels/mono_synth.panel    # generated CtrlrX panel
  svf_cutoff14_to_f.v        # 14-bit cutoff -> SVF f LUT
  svf_cc_to_q.v              # resonance CC -> SVF q LUT
  svf_cc_to_f.v              # legacy/unused helper, not in Makefile
  adsr_regs_to_ctrl4.v       # helper, not in Makefile
  docs/                      # agent-facing docs for this synth
  obj_dir/                   # Verilator artifact, do not commit
```

`Makefile` подключает RTL из корня репозитория через `RTL_SRCS`: `io/midi_in.v`, `mono_voice/mono_voice.v`, `dds/*`, `dds_transform/*`, `adsr/adsr.v`, `common/*`, `svf/*`, `lfo/*`, `vca/*` и локальные LUT.

`panels/*.panel` считается generated artifact. Править источник параметров в `mono_synth.params.yaml`, а панель обновлять генератором.

## Правила Создания Файлов

| Нужно добавить | Куда | Обязательные шаги |
|----------------|------|-------------------|
| Новый MIDI CC / параметр | `../mono_synth.params.yaml` + wiring в `../top.sv` | Обновить `../../../docs/MONO_SYNTH_MIDI.md`; при необходимости перегенерировать CtrlrX panel; не править `panels/*.panel` руками |
| Переиспользуемый RTL-блок | Пакет в корне (`../../../dds/`, `../../../svf/`, `../../../common/`, ...) | Добавить Icarus testbench, запись в `../../../modules.yaml`, `make test`; затем подключить в `../Makefile` `RTL_SRCS` |
| Логика только для `mono_synth` | `../top.sv` или локальный `.v` рядом с ним | Добавить в `../Makefile`; проверить через `scripts/e2e_mono_synth.sh` или targeted smoke |
| Изменение UDP protocol | `../../../hdl-modules-tester/protocol/hdl_net.h` | Синхронизировать копию в `../../../vst_bridge/protocol/`; обновить [`schema.md`](schema.md) и README обоих слоёв |
| Изменение reconnect/session | `../synth_core.cpp` и/или `../../../vst_bridge/` | Проверить [`edge-cases.md`](edge-cases.md); не смешивать VST UI и RTL wiring в одной задаче без причины |
| Документация агента | `./` | README держать index + runbook; большие контракты держать в `docs/` |

## Взаимодействие Модулей

```text
DAW -> VST -> UDP(MidiHostToEngine) -> synth_core -> top.sv:midi_in
  -> note_mono / CC regs / LFO / filter env -> mono_voice -> PCM
  -> synth_core -> UDP(AudioPull) -> VST -> DAW
```

Правила связности:

- `top.sv` связывает блоки и регистры, но не реализует заново DDS/ADSR/SVF.
- `mono_voice/` не знает про UDP, VST, YAML и session lifecycle.
- `hdl-modules-tester/` не содержит synth-specific RTL.
- `vst_bridge/` не содержит RTL и не должен знать внутренние сигналы `top.sv`.
- Параметры идут `mono_synth.params.yaml -> engine schema -> VST APVTS -> MIDI CC bytes -> top.sv`. RTL не читает YAML напрямую.

Подробные структуры, сообщения и правила обмена описаны в [`schema.md`](schema.md). Не-happy-path описан в [`edge-cases.md`](edge-cases.md).

## Важные Ограничения

- `mono_synth` не входит в `modules.yaml` и `make all`; это отдельный Verilator build.
- RTL sample rate фиксирован: `AUDIO_HZ=44100` в `../top.sv`.
- Control port `5004`: одновременно один UDP engine.
- Audio port по умолчанию `5005`.
- `obj_dir/`, `out.vcd`, `testbench` и временные бинарники не коммитить.
- Generated README библиотечных пакетов обновлять только через `make docs`.
- Не трогать `sandbox/`, `verilator_tests/`, `vst_bridge/` или общие модули без связи с текущей задачей в [`current-sprint.md`](current-sprint.md).

## Границы Ответственности

| Компонент | Делает | Не делает |
|-----------|--------|-----------|
| `../top.sv` | MIDI parse wiring, CC -> regs, instantiate voice/filter/LFO | DSP-алгоритмы DDS/ADSR/SVF |
| `../../../mono_voice/` | Oscillator, pitch, ADSR, VCA, optional SVF instance | MIDI, UDP, params schema |
| `../../../hdl-modules-tester/` | UDP, protocol helpers, engine loop, socket code | Synth-specific top или CC mapping |
| `../../../vst_bridge/` | VST3 UI, APVTS, network bridge, forward MIDI/CC | Verilator build, RTL internals |
| `../mono_synth.params.yaml` | Имена параметров, CC, defaults, runtime schema | Реализация DSP или регистров |
| `../../../docs/MONO_SYNTH_MIDI.md` | CC-контракт и опорные точки | Архитектурные границы |
| `./current-sprint.md` | Текущий фокус агента | Полный backlog repo |

## Сделано Для mono_synth

- Verilator + UDP engine `MonoSynth`.
- `note_mono` для monophonic highest-note allocation.
- VCA ADSR CC 16-19, waveform CC 48, PWM duty CC 57.
- Pitch bend -> `note_pitch2dds`.
- SVF inside `mono_voice` with cutoff CC 74/106, resonance CC 71, mode CC 22.
- Filter envelope CC 24-28, key follow CC 51, VCF-LFO3 CC 49/50/52.
- Runtime params schema in `mono_synth.params.yaml`.

См. также фазу B в [`../../../docs/LEGACY_MIGRATION_PLAN.md`](../../../docs/LEGACY_MIGRATION_PLAN.md).

## Перед Любой Правкой

1. Открыть [`current-sprint.md`](current-sprint.md) и убедиться, что задача активна.
2. Открыть этот файл и определить слой.
3. Если меняется контракт, открыть [`schema.md`](schema.md).
4. Если меняется поведение, открыть [`edge-cases.md`](edge-cases.md).
5. Если нужен контекст, искать через [`links.md`](links.md), а не через случайные внешние источники.
