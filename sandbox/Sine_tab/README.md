# Sine_tab — пошаговый LUT-синус

Учебная лестница от прямого `case` до полного синуса. **Библиотечный модуль:** [`dds_transform/dds2sin.v`](../../dds_transform/dds2sin.v) (`WIDTH`, `LUT_BITS`, формула `sin`).

| Каталог | Содержание |
|---------|------------|
| [`v0/`](v0/) | Снимки шагов 1–4 (только индекс / зеркало) |
| [`v1/`](v1/) | Финал sandbox: `sinetabledds.v` + `tbsinetabledds.v` |
| [`v2/`](v2/) | Разнесённые `phase_accumulator` + `phase_to_amplitude_converter` |

## Шаги (v0)

| Шаг | Файл | Индекс | На волне |
|-----|------|--------|----------|
| 1 | `step1_direct.v` | `DDS[31:29]` | 8 ступеней, 1× за период DDS |
| 2 | `step2_idx_30_28.v` | `DDS[30:28]` | 2× за период |
| 3 | `step3_idx_29_27.v` | `DDS[29:27]` | 4× за период |
| 4 | `step4_mirror_dds30.v` | зеркало `DDS[30]` | 4 горба, только положительные |
| 5 | [`v1/sinetabledds.v`](v1/sinetabledds.v) | + знак `DDS[31]` | полный синус вокруг MID |

## Запуск v1

```bash
cd v1
iverilog -o qqq dds.v sinetabledds.v tbsinetabledds.v
vvp qqq
gtkwave out.vcd
```

## Тест в библиотеке

```bash
make test ID=dds_transform
```
