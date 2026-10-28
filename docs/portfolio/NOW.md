# Где я сейчас

Единственный файл, который открывают в новой сессии. Промпт: [SESSION.md](SESSION.md).

```text
phase: P0
gate: passed
next_phase: P1
current_device: sub
current_issue: (нет — P0 закрыт; взять один issue P1)
blocked: нет
updated: 2026-09-25
fhdlgen: 0.4.1
fsoc: 0.1.1
```

## Продолжить

P0 (память в репо) закрыт. Следующая фаза — **P1 экосистема**, один issue:

1. Заполнить MIT-контекст фактами (платы, осциллограф, пайка, бюджет) — иначе агент предлагает нереальное железо; **или**
2. `mono-001` Soft Hello — reconnect без лишнего `rst` ([docs/TODO.md](../TODO.md)).

Не начинать FM, корпуса и новые PCB. Не открывать P2, пока P1 не `gate: passed`.

Текущее устройство портфеля: **`sub`** (цифровой VCO–VCF–ADSR, `synths/mono_synth`). Карточка: [devices/sub.md](devices/sub.md).

## Карта

- Фазы: [ROADMAP.md](ROADMAP.md)
- Статусы устройств: [DEVICES.md](DEVICES.md)
- Журнал: [JOURNAL.md](JOURNAL.md)
