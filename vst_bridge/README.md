# VitaSound Remote Synth (VST3)

VST3-плагин платформы **VitaSound**: MIDI из DAW → UDP engine (Verilator / будущая ПЛИС) → PCM обратно в DAW.

В Reaper: **`VST3i: VitaSound Remote Synth (VitaSound)`**.  
Папка на диске после сборки: **`VitaSound Remote Synth.vst3`** (не `HdlVerilator.vst3` — старый bundle удалить из `VST3/`).

Протокол: [`protocol/hdl_net.h`](protocol/hdl_net.h) (копия [`../verilator_tests/protocol/hdl_net.h`](../verilator_tests/protocol/hdl_net.h)).

## Архитектура

```
DAW (Reaper / Bitwig / FL Studio)
  │ MIDI
  ▼
VitaSound Remote Synth  ──UDP :5004──►  Vgenerator (engine)
  ▲                                        Verilator RTL
  └──UDP :5005 PCM─────────────────────────┘
```

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
| [`../verilator_tests/scripts/build_windows_mingw.sh`](../verilator_tests/scripts/build_windows_mingw.sh) | `Vgenerator.exe` для Windows |
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

Reaper: Clear cache / rescan plugins. В UI должно быть `v0.2.5` и заголовок **VitaSound Remote Synth**.

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
vst_bridge/dist/VitaSound-Remote-Synth-0.2.5-linux-x86_64.zip
vst_bridge/dist/VitaSound-Remote-Synth-0.2.5-windows-x86_64.zip
```

В каждом zip: `VitaSound Remote Synth.vst3` + `INSTALL.txt`.

Linux-сборка требует `./scripts/install_linux_deps.sh` (один раз).

### GitHub Actions

Workflow [`.github/workflows/vst-release.yml`](../.github/workflows/vst-release.yml):

| Триггер | Результат |
|---------|-----------|
| **Actions → vst-release → Run workflow** | Артефакты zip (90 дней) |
| Тег `vst-v0.2.5` (версия = `CMakeLists.txt`) | GitHub Release + zip |

Опубликовать релиз:

```bash
# 1. Поднять VERSION в vst_bridge/CMakeLists.txt
# 2. Закоммитить и запушить
git tag vst-v0.2.5
git push origin vst-v0.2.5
```

Без тега — ручной запуск workflow: zip появятся в **Artifacts** на странице run.

## Запуск: Reaper (Windows) + engine

**Рекомендуемая связка** — engine **native Windows**, VST **Engine host `127.0.0.1`** (без WSL NAT).

### 1. Собрать engine для Windows (из WSL)

```bash
cd verilator_tests
./scripts/build_windows_mingw.sh
```

Скопировать `obj_dir_win/Vgenerator.exe` на Windows и запустить:

```bat
Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

Или `verilator_tests/scripts/run_udp_engine_win.bat`.

### 2. Собрать и установить VST

```bash
cd vst_bridge
./scripts/build_windows_mingw.sh
```

Скопировать `.vst3` в `C:\Program Files\Common Files\VST3\`, rescan.

### 3. Reaper

- MIDI-трек → **VitaSound Remote Synth**
- **Engine host:** `127.0.0.1`
- **Jitter buffer:** 60–120 ms (UDP); начать с 80 ms
- **Play** — снять mute после Stop
- **Test note OFF/ON** — длительный тон для проверки буфера
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

| Элемент | Описание |
|---------|----------|
| Engine host | IP engine (`127.0.0.1` для native Windows engine) |
| Jitter buffer | Задержка PCM (10–200 ms); подсказка: recommended 60–120 for UDP |
| Reconnect | Сброс буфера, новый HELLO |
| Play / Stop | Unmute / mute + All Notes Off |
| Test note | Note On/Off (C4) для проверки длительного тона |
| Reset stats | Обнулить Underruns |
| Buffered / Underruns | Диагностика; при стабильном звуке Underruns не растут |

## Файлы

| Путь | Назначение |
|------|------------|
| `Source/PluginProcessor.cpp` | MIDI → NetBridge, PCM → DAW |
| `Source/NetBridge.cpp` | UDP, jitter FIFO |
| `Source/PluginEditor.cpp` | UI |
| `protocol/hdl_net.h` | Протокол с engine |

## MIDI over UDP (будущее)

MVP — проектный `hdl_net`. Возможные стандарты: [RTP-MIDI](https://www.rfc-editor.org/rfc/rfc6295), [Network MIDI 2.0](https://midi.org/network-midi-2-0).
