# ssaw — синтезатор с supersaw

```text
virtual: not_started
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Несколько расстроенных пил (типично 7), дальше фильтр и огибающая по образцу `sub`.

- Виртуальная база: `voice_ssaw` в fpga-synth (фаза C, не портирован).
- Главный пробел: порт в `modules.yaml` + `synths/supersaw`.

## Модули

- Есть: dds, detune/LFO куски в `note_pitch2dds`.
- Нужно: `voice_ssaw` в стиле hdl-modules, mix нескольких DDS.

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). Эталон: слышен detune, не биение одного осциллятора.

## На железе проверить

Загрузка FPGA (много умножителей/аккумуляторов), клиппинг суммы.
