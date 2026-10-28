# fmd — FM-ударные

```text
virtual: not_started
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Барабанная установка на FM: качественно и просто. 2-op + шум + короткие огибающие. Панель проще, чем у `fm`.

- Виртуальная база: тот же оператор, что у `fm`, плюс `rnd`, короткие env.
- Главный пробел: 8–11 ячеек (kick, snare, hats, toms…), простая карта MIDI note → ячейка.

## Модули

- Есть: rnd, adsr, sin.
- Нужно: 2-op FM voice, noise mix, trigger по note, набор ячеек.

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). Эталон: kick/snare/hat узнаются без объяснений; не «мелодия на FM».

## На железе проверить

Полифония ячеек, клик атаки, громкость шума.
