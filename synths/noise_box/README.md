# noise_box

Шумовой синт: [`rnd/rndx.v`](../../rnd/rndx.v) с `WIDTH=16`. Звук при любой **Note On**, тишина когда все ноты отпущены (**Note Off** / All Notes Off).

UDP pull-mode engine для **VitaSound Remote Synth** (тот же протокол, что [`hdl-modules-tester`](../../hdl-modules-tester/)).

## Сборка

```bash
cd synths/noise_box
make clean && make
```

Бинарник: `obj_dir/NoiseBox`

## Запуск

Из корня репо:

```bash
./scripts/run_noise_box.sh
```

Или вручную (остановите другой engine на :5004):

```bash
fuser -k 5004/udp 2>/dev/null || true
./synths/noise_box/obj_dir/NoiseBox --udp-bind 0.0.0.0:5004
```

В VST: **Play**, любая нота → белый шум, отпускание → тишина.

## Smoke без DAW

```bash
make -C synths/noise_box
./synths/noise_box/obj_dir/NoiseBox &
sleep 1
python3 hdl-modules-tester/scripts/udp_smoke_test.py --duration 2
```

## RTL

- `top.sv` — `noise_box`, `enable` от `engine` (полифонический gate)
- `../../rnd/rndx.v` — LFSR, параметр `WIDTH=16`
