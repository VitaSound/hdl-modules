# hyb — VCO–VCF–ADSR с аналоговым фильтром

```text
virtual: not_started
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Тот же голос, что `sub`, но cutoff/resonance — аналоговый VCF. Цифровой фильтр в виртуале = заглушка CV.

- Виртуальная база: `sub` + PWM CV.
- Главный пробел: CV на пин; аналог в `fpga-synth/schemes/VCF`.
- Зависит от: `sub` virtual хотя бы как эталон тембра без фильтра.

## Модули

- Есть: голос `sub`, PWM DAC в legacy fpga-synth (`vca_pwm8dac1`, `pwm8dac1`).
- Нужно: CV-выход в библиотеке `io/`, модель «цифровой SVF выключен / CV вместо него».

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). В DAW достаточно слышать осциллятор + огибающую CV (или лог CV). Сам аналоговый тембр — ворота железа.

## На железе проверить

Шкала CV, калибровка cutoff, питание аналоговой платы, земля.
