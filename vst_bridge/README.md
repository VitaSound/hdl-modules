# VitaSound Remote Synth (VST3)

VST3-плагин платформы **VitaSound**: MIDI из DAW → UDP engine (Verilator / будущая ПЛИС) → PCM обратно в DAW.

**Версия:** 0.5.0 — см. [CHANGELOG.md](CHANGELOG.md).

В Reaper: **`VST3i: VitaSound Remote Synth (VitaSound)`**.  
Папка на диске после сборки: **`VitaSound Remote Synth.vst3`** (не `HdlVerilator.vst3` — старый bundle удалить из `VST3/`).

Протокол: [`protocol/hdl_net.h`](protocol/hdl_net.h) (копия [`../hdl-modules-tester/protocol/hdl_net.h`](../hdl-modules-tester/protocol/hdl_net.h)).

## Архитектура

```
DAW (Reaper / Bitwig / FL Studio)
  │ MIDI + AudioPull
  ▼
VitaSound Remote Synth  ──UDP :5004──►  Vgenerator (engine)
  ▲                                        Verilator RTL
  └──UDP :5005 PCM (on pull)───────────────┘
```

Протокол **v4 (pull + optional push)**: хост запрашивает PCM через `AudioPull`; при `kCapAudioPush` (MiniFX) хост шлёт dry через **AudioPush**.

## APVTS parameters (mono_synth)

Источник: [`synths/mono_synth/mono_synth.params.yaml`](../synths/mono_synth/mono_synth.params.yaml) → `tools/gen_vst_apvts.py` → `generated/SynthParams.{h,cpp}`.

Плагин регистрирует именованные параметры для automation/presets. Изменение → MIDI CC → UDP engine (dual path с CtrlrX panel).

Regenerate:

```bash
python3 tools/gen_vst_apvts.py
```

UI: верх панели — **GenericAudioProcessorEditor** (Synth params); ниже — Network/transport.

## CtrlrX panel

См. [`docs/CTRLRX_PANEL.md`](../docs/CTRLRX_PANEL.md). Patcher: CtrlrX → VitaSound.

## MiniFX (AudioPush test)

[`synths/mini_fx/`](../synths/mini_fx/) + [`scripts/run_mini_fx.sh`](../scripts/run_mini_fx.sh). Insert on track; VitaSound pushes input when engine advertises `kCapAudioPush`.

## Скрипты сборки

Все скрипты в **`vst_bridge/scripts/`** (запускать из `vst_bridge/` или с полным путём).

| Скрипт | Назначение |
|--------|------------|
| [`scripts/build_windows_mingw.sh`](scripts/build_windows_mingw.sh) | **Windows VST из WSL/Ubuntu** (основной сценарий для Reaper на Win) |
| [`scripts/build_linux.sh`](scripts/build_linux.sh) | Linux VST3 (Reaper/Bitwig в Ubuntu) |
| [`scripts/install_linux_deps.sh`](scripts/install_linux_deps.sh) | Зависимости JUCE для Linux (один раз) |
| [`scripts/install_windows_vst.sh`](scripts/install_windows_vst.sh) | Копирование в `C:\Program Files\Common Files\VST3\` + удаление старого `HdlVerilator.vst3` |
| [`scripts/build_release.sh`](scripts/build_release.sh) | **Релиз:** сборка Linux + Windows → zip в `dist/` |

Engine (не VST):

| Скрипт | Назначение |
|--------|------------|
| [`../hdl-modules-tester/scripts/build_windows_mingw.sh`](../hdl-modules-tester/scripts/build_windows_mingw.sh) | `Vgenerator.exe` для Windows |
| [`../scripts/run_udp_engine.sh`](../scripts/run_udp_engine.sh) | Engine в WSL/Linux (`obj_dir/Vgenerator`) |

## Сборка VST

### Windows Reaper — cross-compile из WSL (рекомендуется)

```bash
cd /path/to/hdl-modules/vst_bridge
./scripts/build_windows_mingw.sh          # инкрементально (~1–2 мин)
./scripts/build_windows_mingw.sh --clean  # полная пересборка
```

Результат (после `PRODUCT_NAME` в CMake):

```
vst_bridge/build-win/HdlVerilator_artefacts/Release/VST3/VitaSound Remote Synth.vst3
```

Установка (из WSL):

```bash
./scripts/install_windows_vst.sh
```

Или вручную — **удалить старый** `HdlVerilator.vst3`, затем скопировать новый bundle:

```
\\wsl$\...\vst_bridge\build-win\...\VitaSound Remote Synth.vst3
  → C:\Program Files\Common Files\VST3\
```

Reaper: Clear cache / rescan plugins. В UI должно быть `v0.3.1` и строка build с git hash (например `0.3.1+abc1234+...`).

**После каждой пересборки** (`cmake --build build-win`) нужно **заново скопировать** `VitaSound Remote Synth.vst3` в `C:\Program Files\Common Files\VST3\` (или `./scripts/install_windows_vst.sh`) и сделать rescan — иначе Reaper оставит старый bundle.

Первый запуск скачивает **llvm-mingw** в `vst_bridge/.toolchains/`.

### Linux DAW (Reaper в Ubuntu)

```bash
cd vst_bridge
chmod +x scripts/install_linux_deps.sh scripts/build_linux.sh
./scripts/install_linux_deps.sh   # один раз
./scripts/build_linux.sh
```

Результат: `vst_bridge/build/HdlVerilator_artefacts/Release/VST3/VitaSound Remote Synth.vst3`

```bash
cp -r "build/HdlVerilator_artefacts/Release/VST3/VitaSound Remote Synth.vst3" ~/.vst3/
```

### Windows нативно (Visual Studio)

```powershell
cd vst_bridge
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

## Релиз (Linux + Windows zip)

Версия берётся из `CMakeLists.txt` (`project(... VERSION x.y.z)`).

```bash
cd vst_bridge
./scripts/build_release.sh              # обе платформы → dist/
./scripts/build_release.sh --clean      # чистая пересборка
./scripts/build_release.sh --windows-only
./scripts/build_release.sh --linux-only
./scripts/build_release.sh --skip-build # только упаковать уже собранное
```

Артефакты:

```
vst_bridge/dist/VitaSound-Remote-Synth-0.3.1-linux-x86_64.zip
vst_bridge/dist/VitaSound-Remote-Synth-0.3.1-windows-x86_64.zip
```

В каждом zip: `VitaSound Remote Synth.vst3` + `INSTALL.txt`.

Linux-сборка требует `./scripts/install_linux_deps.sh` (один раз). На **Ubuntu 24.04** пакет WebKit: `libwebkit2gtk-4.1-dev` (скрипт выбирает автоматически).

MIDI CC из DAW: **16–19** (ADSR), **48** (waveform) — engine [`../synths/mono_synth/`](../synths/mono_synth/). Legacy MIDI без DAW: [`../verilator_tests/README.md`](../verilator_tests/README.md) (`VgeneratorFull`).

### GitHub Actions

Workflow [`.github/workflows/vst-release.yml`](../.github/workflows/vst-release.yml):

| Триггер | Результат |
|---------|-----------|
| **Actions → vst-release → Run workflow** | Артефакты zip (90 дней) |
| Тег `v0.5.0` (версия = [`VERSION`](../VERSION)) | GitHub Release: VST3 + UDP engine + legacy engine |

Опубликовать релиз:

```bash
# 1. Поднять VERSION в корне репо и vst_bridge/CMakeLists.txt
# 2. Закоммитить и запушить
git tag v0.5.0
git push origin v0.5.0
```

Без тега — ручной запуск workflow: zip появятся в **Artifacts** на странице run.

## Запуск: Reaper (Windows) + engine

**Рекомендуемая связка** — engine **native Windows**, VST **Engine host `127.0.0.1`** (без WSL NAT).

### 1. Собрать engine для Windows (из WSL)

```bash
cd hdl-modules-tester
./scripts/build_windows_mingw.sh
```

Скопировать `obj_dir_win/Vgenerator.exe` на Windows и запустить:

```bat
Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

Или `hdl-modules-tester/scripts/run_udp_engine_win.bat`.

### 2. Собрать и установить VST

```bash
cd vst_bridge
./scripts/build_windows_mingw.sh
```

Скопировать `.vst3` в `C:\Program Files\Common Files\VST3\`, rescan.

### 3. Reaper

- MIDI-трек → **VitaSound Remote Synth**
- **Engine host:** `127.0.0.1`
- **Network profile:** WSL для engine в WSL2; Local для native `Vgenerator.exe`
- **Reserve packets:** auto-tune подстраивает min/target; при Bursty delivery буфер не уменьшается
- **Play** / **Stop** — режим воспроизведения (лампочки на кнопках)
- **Test note** — длительный тон C4 (toggle, зелёная лампа)
- Audio: WASAPI exclusive, **48000 Hz**, block **512–1024**

Firewall: разрешить UDP **5004** (control) и **5005** (audio) на Windows.

Подробнее о сети WSL: [docs/WSL_NETWORKING.md](../docs/WSL_NETWORKING.md).

### Альтернатива: engine в WSL2

```bash
# из корня репо
./scripts/run_udp_engine.sh
```

В VST указать IP WSL (`hostname -I` в Linux). На WSL2 UDP менее стабилен — см. mirrored networking в [docs/WSL_NETWORKING.md](../docs/WSL_NETWORKING.md).

## E2E без DAW

```bash
# из корня репо
./scripts/e2e_ubuntu.sh
```

## UI плагина

![VitaSound Remote Synth UI](docs/ui.png)

| Элемент | Описание |
|---------|----------|
| ● у Engine host | Соединение: красный / оранжевый (Ack) / зелёный (стрим) |
| Engine host + Reconnect | IP engine; Reconnect — сброс буфера и новый HELLO |
| Min / target / warmup reserve | Запас PCM в пакетах (256 samples/pkt); pull v2 |
| Network profile | Auto / WSL / Local / LAN — стартовые буферы и auto-tune |
| Auto-tune | Быстро растёт при underrun/Bursty; медленно снижает при Smooth |
| Test note / Play / Stop | Панельные кнопки с лампочкой: test note (toggle), Play (зелёная), Stop (красная) |
| Buffer bar | Fill / target пакетов |
| Reset stats | Ссылка справа внизу — обнулить Underruns / Pulls |
| Status / stats | Fill, latency, p95 jitter, Smooth/Bursty, pulls |

## Файлы

| Путь | Назначение |
|------|------------|
| `Source/PluginProcessor.cpp` | MIDI → NetBridge, PCM → DAW |
| `Source/NetBridge.cpp` | UDP pull scheduler, delivery quality monitor |
| `Source/PluginEditor.cpp` | UI |
| `protocol/hdl_net.h` | Протокол с engine |

## MIDI over UDP (будущее)

MVP — проектный `hdl_net`. Возможные стандарты: [RTP-MIDI](https://www.rfc-editor.org/rfc/rfc6295), [Network MIDI 2.0](https://midi.org/network-midi-2-0).
