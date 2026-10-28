# chip — чиптюн

```text
virtual: not_started
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Квадрат/PWM/шум, каналность в духе AY-3-8910 / YM2149, не «аналоговый» фильтр.

- Виртуальная база: `dds_transform` square/PWM + `rnd`; YM2149 в `fpga-synth/examples`.
- Главный пробел: `synths/chip` / AY-ядро в библиотеке.

## Модули

- Есть: square, pwm, rnd.
- Нужно: тон-генератор чиптюна или порт YM2149, микшер каналов.

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). Эталон: 3 канала + шум, узнаваемый «8-bit» тембр.

## На железе проверить

Точность частот, клик при смене ноты, громкость каналов.
