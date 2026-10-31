# VitaSound engines + Remote

Публичная модель: один VST-мост и много UDP engines. Каталоги `synths/<id>/` — исходники; zip/binary — публичные имена ниже.

## Компоненты

| Роль | Публичное имя | Тип | Каталог | Sample rate |
|------|---------------|-----|---------|-------------|
| Мост в DAW | **VitaSound Remote** (VST3 effect) | host | [`vst_bridge/`](../vst_bridge/) | как у DAW / Hello |
| Одноголосный синт | **VitaSound-Engine-mono_synth** | synth | [`synths/mono_synth/`](../synths/mono_synth/) | **48000** |
| Insert FX | **VitaSound-Engine-mini_fx** | fx | [`synths/mini_fx/`](../synths/mini_fx/) | **48000** |
| Шум | **VitaSound-Engine-noise_box** | synth | [`synths/noise_box/`](../synths/noise_box/) | **48000** |
| MVP (CI / smoke) | `HdlModulesTester` / `Vgenerator` | — | [`hdl-modules-tester/`](../hdl-modules-tester/) | 48000; не для «скачай и играй» |

Правило имени engine: `VitaSound-Engine-<id>`, где `<id>` = имя каталога в `synths/`. Портфельный id (`sub`) — только в [`docs/portfolio/`](portfolio/).

Типы:

- **synth** — MIDI → PCM (Play / Test note / piano roll)
- **fx** — AudioPush + AudioPull (insert на аудио-трек)

На UDP **:5004** одновременно только один engine. PCM — **:5005**.

## Релизные архивы

```text
VitaSound-Remote-<ver>-{linux,windows}-x86_64.zip
  └── VitaSound Remote.vst3

VitaSound-Engine-mono_synth-<ver>-{linux,windows}-x86_64.zip
  └── VitaSound-Engine-mono_synth[.exe]
  └── README.txt

VitaSound-Engine-mini_fx-<ver>-{linux,windows}-x86_64.zip
  └── …

VitaSound-Engine-noise_box-<ver>-{linux,windows}-x86_64.zip
  └── …
```

Внутренние артефакты сборки Linux: `synths/<id>/obj_dir/{MonoSynth,MiniFX,NoiseBox}` — упаковщик переименовывает в `VitaSound-Engine-<id>`. Windows: `obj_dir_win/VitaSound-Engine-<id>.exe`.

## Runbook (Windows + DAW)

1. Установить **VitaSound Remote.vst3** → `C:\Program Files\Common Files\VST3\`, rescan.
2. Запустить engine, например `VitaSound-Engine-mono_synth.exe` (или в WSL: `./scripts/run_mono_synth.sh`).
3. DAW project / audio: **48000 Hz**, buffer 512–1024.
4. Insert **VitaSound Remote** (effect, не instrument):
   - synth → MIDI-трек;
   - fx → аудио-трек.
5. Engine host `127.0.0.1`, Network profile Local (native) или WSL, **Play** → Test note / ноты.

Разработка (WSL): [`docs/WSL_NETWORKING.md`](WSL_NETWORKING.md).

## Локальная сборка

```bash
make -C synths/mono_synth
./scripts/run_mono_synth.sh

# Windows .exe из WSL:
./scripts/build_synth_windows_mingw.sh mono_synth
./scripts/package_engine_release.sh "$(tr -d '[:space:]' < VERSION)" dist
# PACKAGE_TARGET=engine-mono_synth-windows  (см. скрипт)
```

VST:

```bash
cd vst_bridge && ./scripts/build_windows_mingw.sh && ./scripts/install_windows_vst.sh
```

## Ссылки

- Ручная проверка трёх ядер: [`TEST_ENGINES.md`](TEST_ENGINES.md)
- [`synths/README.md`](../synths/README.md)
- [`vst_bridge/README.md`](../vst_bridge/README.md)
- [`docs/MONO_SYNTH_MIDI.md`](MONO_SYNTH_MIDI.md)
- Portfolio device `sub` → engine id `mono_synth`: [`portfolio/devices/sub.md`](portfolio/devices/sub.md)
