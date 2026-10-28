# mix — микшер

```text
virtual: not_started
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Класс: микшер. Уровни, маршрутизация, суммирование, mute/solo, панорама, пресеты.

- Виртуальная база: сумматор шин на AudioPush.
- Главный пробел: нет mix-bus в библиотеке.

## Модули

- Есть: VCA, param_reg, stereo PCM.
- Нужно: mix-bus, mute/solo/pan, пресеты (хотя бы в host/VST на v1).

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). Эталон: несколько входов, слышны уровни и mute.

## На железе проверить

Перегрузка суммы, фантом/земля (если будут mic), задержка мониторинга.
