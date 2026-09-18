# AI_INDEX — индекс модулей hdl-modules

Индекс RTL-модулей репозитория [VitaSound/hdl-modules](https://github.com/VitaSound/hdl-modules) (ветка `master`) для ИИ-агентов.
Обзор для людей — [README.md](README.md), правила работы в репозитории — [AGENTS.md](AGENTS.md).

## Как читать этот индекс

- Всё перечисленное ниже имеет статус **готово**: модуль лежит в репозитории и покрыт симуляцией Icarus Verilog (`make test`).
- **Порты не дублируются** — объявление модуля смотреть в исходном `.v`.
- Колонка «Тест» — каталог с `testbench.v`, `test.sh`, `test.gtkw`; запуск одного модуля: `make sim ID=<id>`.
- Колонка «Waveform» — PNG, сгенерированный из `out.vcd` через GTKWave (`make images ID=<id>`).
- Полный список `sources` для `iverilog` (включая зависимости) — в [modules.yaml](modules.yaml).
- Список id: `make list`.

Если нужного блока здесь нет, значит в этом репозитории он не реализован — задачу на разработку ставить со ссылкой на этот файл.

## Common

Модули общего назначения и вспомогательные. README категории: [common/README.md](common/README.md).

| Модуль | Статус | Назначение | Исходник | Тест | Waveform |
| ------ | ------ | ---------- | -------- | ---- | -------- |
| `powerup_reset` | готово | Генератор автоматического сигнала сброса и сброса по кнопке | [common/powerup_reset.v](common/powerup_reset.v) | [common/powerup_reset_test](common/powerup_reset_test) | [png](common/powerup_reset_test/test.png) |
| `frqdivmod` | готово | Целочисленный делитель частоты на 2, 3, 4 итд | [common/frqdivmod.v](common/frqdivmod.v) | [common/frqdivmod_test](common/frqdivmod_test) | [png](common/frqdivmod_test/test.png) |
| `strobe_gen` | готово | Формирователь строба шириной 1 clk от нч сигнала (например, от целочисленного делителя) | [common/strobe_gen.v](common/strobe_gen.v) | [common/strobe_gen_test](common/strobe_gen_test) | [png](common/strobe_gen_test/test.png) |
| `param_reg` | готово | Регистр параметра с записью по strobe wr (param_reg WIDTH; обёртки reg7 — MIDI CC, reg14 — ADSR A/D/R, pitch) | [common/param_reg.v](common/param_reg.v) | [common/param_reg_test](common/param_reg_test) | [png](common/param_reg_test/test.png) |
| `reg_sr` | готово | SR-регистр gate: set (NoteOn) / reset (NoteOff); замена legacy reg_rs | [common/reg_sr.v](common/reg_sr.v) | [common/reg_sr_test](common/reg_sr_test) | [png](common/reg_sr_test/test.png) |

## I/O (граница ПЛИС)

Интерфейсы с внешним миром; к модулям обычно прилагается внешняя схема (опторазвязка MIDI IN, ЦАП). README категории: [io/README.md](io/README.md).

| Модуль | Статус | Назначение | Исходник | Тест | Waveform |
| ------ | ------ | ---------- | -------- | ---- | -------- |
| `midi_in` | готово | MIDI byte parser: channel voice → ch_message/lsb/msb; SysEx skip (v1); UART — на плате | [io/midi_in.v](io/midi_in.v) | [io/midi_in_test](io/midi_in_test) | [png](io/midi_in_test/test.png) |

## Генерация

Модули синтеза звука: осцилляторы, огибающие, VCA, фильтры, шум.

| Модуль | Статус | Назначение | Исходник | Тест | Waveform | README |
| ------ | ------ | ---------- | -------- | ---- | -------- | ------ |
| `dds` | готово | Генератор базовой цифровой пилы | [dds/dds.v](dds/dds.v) | [dds/test](dds/test) | [png](dds/test/test.png) | [dds/README.md](dds/README.md) |
| `note2dds` | готово | MIDI note → DDS phase increment; таблица 12 semitones, параметр CLK_HZ | [dds/note2dds.v](dds/note2dds.v) | [dds/note2dds_test](dds/note2dds_test) | [png](dds/note2dds_test/test.png) | — |
| `note_pitch2dds` | готово | Note + pitch wheel + LFO pitch → DDS adder (dual note2dds + interp) | [dds/note_pitch2dds.v](dds/note_pitch2dds.v) | [dds/note_pitch2dds_test](dds/note_pitch2dds_test) | [png](dds/note_pitch2dds_test/test.png) | — |
| `mono_voice` | готово | Моно-голос: note_pitch2dds → dds → mux форм → adsr → vca; OUT_WIDTH параметр (дефолт 16) | [mono_voice/mono_voice.v](mono_voice/mono_voice.v) | [mono_voice/test](mono_voice/test) | [png](mono_voice/test/test.png) | [mono_voice/README.md](mono_voice/README.md) |
| `dds_transform` | готово | Преобразователи формы базовой цифровой пилы и синус | [dds/dds.v](dds/dds.v) | [dds_transform/test](dds_transform/test) | [png](dds_transform/test/test.png) | [dds_transform/README.md](dds_transform/README.md) |
| `vca` | готово | Модули VCA. 8 и 32 битные. Формат данных целочисленный без знака. То есть от 0 до N с центром в N/2. | [vca/svca.v](vca/svca.v) | [vca/test](vca/test) | [png](vca/test/test.png) | [vca/README.md](vca/README.md) |
| `rnd` | готово | Модули генерации псевдослучайных чисел 1, 8, n бит. | [rnd/rnd1.v](rnd/rnd1.v) | [rnd/test](rnd/test) | [png](rnd/test/test.png) | [rnd/README.md](rnd/README.md) |
| `adsr` | готово | Генератор огибающей ADSR | [adsr/adsr.v](adsr/adsr.v) | [adsr/test](adsr/test) | [png](adsr/test/test.png) | [adsr/README.md](adsr/README.md) |
| `lfo` | готово | Низкочастотный осциллятор (DDS + выбираемая форма); rate7 → 0.1–30 Hz @ 1 MHz; выход 0..255 центр 128 | [lfo/lfo.v](lfo/lfo.v) | [lfo/test](lfo/test) | [png](lfo/test/test.png) | — |
| `svf_fcut_mix` | готово | Сумматор cutoff SVF: manual + key follow + LFO + filter env; clamp 14-bit | [svf/svf_fcut_mix.v](svf/svf_fcut_mix.v) | [svf/svf_fcut_mix_test](svf/svf_fcut_mix_test) | [png](svf/svf_fcut_mix_test/test.png) | — |
| `svf` | готово | Цифровой state-variable фильтр Chamberlin: HP, BP, LP, notch за один `tick`. | [svf/svf.v](svf/svf.v) | [svf/test](svf/test) | [png](svf/test/test.png) | [svf/README.md](svf/README.md) |

### Варианты внутри пакетов

- `dds_transform`:
    - [dds_transform/dds2saw.v](dds_transform/dds2saw.v) — пила
    - [dds_transform/dds2revsaw.v](dds_transform/dds2revsaw.v) — обратная пила
    - [dds_transform/dds2tria.v](dds_transform/dds2tria.v) — треугольник
    - [dds_transform/dds2square.v](dds_transform/dds2square.v) — меандр
    - [dds_transform/dds2pwm.v](dds_transform/dds2pwm.v) — PWM c 7-битной регулировкой %
    - [dds_transform/dds2sin.v](dds_transform/dds2sin.v) — синус (WIDTH, LUT_BITS; дефолт 32×8 точек)
- `vca`:
    - [vca/svca.v](vca/svca.v) — vca 8bit cv, in, out
    - [vca/svca_wide.v](vca/svca_wide.v) — vca 8bit cv, in, 16bit out
    - [vca/svca16.v](vca/svca16.v) — vca 16bit signed in/cv, uint16 out
    - [vca/svca32.v](vca/svca32.v) — vca 32 bit cv, in, out
- `rnd`:
    - [rnd/rnd1.v](rnd/rnd1.v) — rnd 1bit
    - [rnd/rnd8.v](rnd/rnd8.v) — rnd 8 bit
    - [rnd/rndx.v](rnd/rndx.v) — rnd x bit (1..32)

## Синтезаторы и runtime (вне библиотеки модулей)

Эти каталоги не входят в `modules.yaml` и не проверяются `make test`:

- `synths/mono_synth/` — моно-синтезатор на Verilator + UDP; документация для агента в `synths/mono_synth/docs/` (начинать с `current-sprint.md`)
- `synths/mini_fx/` — insert-эффект (SVF) для AudioPush
- `synths/noise_box/` — генератор шума
- `hdl-modules-tester/` — UDP engine для VST (pull-only)
- `vst_bridge/` — плагин VST3 (VitaSound Remote Synth)
- `verilator_tests/` — legacy путь «клавиатура/MIDI → звуковая карта»

## Экосистема VitaSound

- [MIT](https://github.com/VitaSound/MIT) — методология и декомпозиция задач (виртуальное «Министерство Инженерных Технологий»)
- [feco](https://github.com/VitaSound/feco) — каталог Forth-инструментов (fmix, flint, fcov, fmcp)
- [fhdlgen](https://github.com/VitaSound/fhdlgen) — генератор Verilog из Forth (будущий фронтенд для этой библиотеки)

<!-- generated by tools/gen_readme.py -->
