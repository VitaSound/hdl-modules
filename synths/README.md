# synths

UDP engines для отладки RTL «на слух» через **VitaSound Remote** (VST3).

Публичные имена, sample rate (**48000**), zip: [`docs/ENGINES.md`](../docs/ENGINES.md).

| Каталог | Публичный binary | Тип | Описание |
|---------|------------------|-----|----------|
| [`mono_synth/`](mono_synth/) | `VitaSound-Engine-mono_synth` | synth | Моно-голос: note_mono + ADSR/wave + mono_voice |
| [`mini_fx/`](mini_fx/) | `VitaSound-Engine-mini_fx` | fx | Insert SVF (AudioPush + AudioPull) |
| [`noise_box/`](noise_box/) | `VitaSound-Engine-noise_box` | synth | 16-bit шум (`rndx`), gate от MIDI-ноты |

## Паттерн

```
synths/<name>/
  top.sv              # Verilator top
  synth_core.cpp/h    # адаптер RTL → PCM
  main.cpp            # точка входа
  Makefile            # + ../../hdl-modules-tester/{engine,net_socket}.cpp
```

Общий UDP-стек: [`hdl-modules-tester/`](../hdl-modules-tester/). VST: [`vst_bridge/`](../vst_bridge/).

На порту **5004** одновременно может работать только один engine.

## WavePeek (offline VCD)

Для запросов через WavePeek соберите с `TRACE=1` и сделайте короткий dump без UDP:

```bash
make -C synths/mono_synth TRACE=1
./synths/mono_synth/obj_dir/MonoSynth \
  --dump-vcd synths/mono_synth/out.vcd --dump-frames 1024 --dump-note 60
make peek ID=mono_synth ARGS='info'

make -C synths/mini_fx TRACE=1
./synths/mini_fx/obj_dir/MiniFX --dump-vcd synths/mini_fx/out.vcd --dump-frames 1024
make peek ID=mini_fx ARGS='scope --tree'

make -C synths/noise_box TRACE=1
./synths/noise_box/obj_dir/NoiseBox \
  --dump-vcd synths/noise_box/out.vcd --dump-frames 1024 --dump-note 60
make peek ID=noise_box ARGS='info'
```

Не коммитить `out.vcd` / `obj_dir/`.
