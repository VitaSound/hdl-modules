# Где я сейчас

Единственный файл, который открывают в новой сессии. Промпт: [SESSION.md](SESSION.md).

```text
phase: P0
gate: passed
next_phase: P1
current_device: sub
current_issue: (нет — ждать явной цели; mono-001 cancelled)
blocked: нет
updated: 2026-10-28
fhdlgen: 0.4.1
fsoc: 0.1.1
```

## Продолжить

P0 (память в репо) закрыт. `sub` / `mono_synth` уже слушается через VSTi — не трогать без реальной боли.

`mono-001` Soft Hello — **cancelled** (не актуально).

Следующая фаза — **P1 экосистема**, только по явной цели пользователя (например MIT-контекст: платы, осциллограф, пайка, бюджет). Не предлагать polish из TODO ради галочки.

Не начинать FM, корпуса и новые PCB. Не открывать P2, пока P1 не `gate: passed`.

Текущее устройство портфеля: **`sub`** (цифровой VCO–VCF–ADSR, `synths/mono_synth`). Карточка: [devices/sub.md](devices/sub.md).

## Карта

- Фазы: [ROADMAP.md](ROADMAP.md)
- Статусы устройств: [DEVICES.md](DEVICES.md)
- Журнал: [JOURNAL.md](JOURNAL.md)
