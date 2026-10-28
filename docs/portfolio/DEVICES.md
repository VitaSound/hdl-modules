# Устройства портфеля

Статусы: `not_started` · `in_progress` · `done` · `blocked` · `skipped`.

DoD виртуала (колонка virtual → `done`):

- контракт: входы/выходы, MIDI CC, что слышно;
- RTL в библиотеке или явно «только top»;
- Icarus self-check;
- `synths/<id>` играет из REAPER/CtrlrX;
- 5 эталонных пресетов или WAV;
- список «что проверять на железе».

| id | Устройство | virtual | hardware | id (корпус) | sale | Карточка |
|----|------------|---------|----------|-------------|------|----------|
| `if` | звуковая плата | not_started | not_started | not_started | not_started | [devices/if.md](devices/if.md) |
| `mix` | микшер | not_started | not_started | not_started | not_started | [devices/mix.md](devices/mix.md) |
| `gtr` | гитарный процессор | not_started | not_started | not_started | not_started | [devices/gtr.md](devices/gtr.md) |
| `sub` | цифровой VCO–VCF–ADSR | in_progress | not_started | not_started | not_started | [devices/sub.md](devices/sub.md) |
| `hyb` | то же + аналоговый VCF | not_started | not_started | not_started | not_started | [devices/hyb.md](devices/hyb.md) |
| `ssaw` | supersaw | not_started | not_started | not_started | not_started | [devices/ssaw.md](devices/ssaw.md) |
| `chip` | чиптюн | not_started | not_started | not_started | not_started | [devices/chip.md](devices/chip.md) |
| `fm` | FM «как DX7» | not_started | not_started | not_started | not_started | [devices/fm.md](devices/fm.md) |
| `fmd` | FM-ударные | not_started | not_started | not_started | not_started | [devices/fmd.md](devices/fmd.md) |

`sub` уже имеет работающий `synths/mono_synth` (VST/UDP). Backlog `mono-001`…`007` — в [docs/TODO.md](../TODO.md).
