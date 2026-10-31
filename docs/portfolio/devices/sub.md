# sub — цифровой VCO–VCF–ADSR

```text
virtual: in_progress
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Класс: синтезатор. Полностью цифровой классический голос: осциллятор, SVF, ADSR, VCA.

- Виртуальная база: **`synths/mono_synth`** + `mono_voice` + `svf`.
- Публичный engine id / binary: **`VitaSound-Engine-mono_synth`** (не `sub`); см. [ENGINES.md](../../ENGINES.md). Sample rate **48000**.
- Главный пробел: backlog `mono-002`…`007` ([docs/TODO.md](../../TODO.md)); закрыть как эталон портфеля.

## Модули

- Есть: dds, dds_transform, note2dds, adsr, vca, lfo, svf, midi_in (parser), mono_voice, UDP/VST.
- Нужно: phase-sync legato, сверка LFO→pitch; Soft Hello / 48k platform default — закрыты или wontfix.

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). Частично выполнено: играет из DAW. Не закрывать virtual, пока эталонный слуховой чеклист в TODO (CtrlrX, high-Q, filter env) и критичные `mono-001`…`003` не закрыты или явно отложены в JOURNAL.

## На железе проверить

Клок 48 kHz, MIDI DIN, PWM/I2S тон, нет клиппинга на выходе.
