# vst_bridge — VST3 bridge to Verilator engine

VST3-плагин (JUCE): принимает MIDI от DAW, отправляет события по UDP engine, получает PCM обратно и отдаёт в DAW.

## Архитектура

```
DAW (FL Studio / Reaper / Bitwig)
  │ MIDI
  ▼
HdlVerilator.vst3  ──UDP :5004──►  verilator_tests (engine)
  ▲                                  Verilator RTL
  └──UDP :5005 PCM───────────────────┘
```

Протокол: [`protocol/hdl_net.h`](protocol/hdl_net.h) (копия из [`../verilator_tests/protocol/hdl_net.h`](../verilator_tests/protocol/hdl_net.h)).

## Сборка

### Windows (приоритет)

1. [CMake](https://cmake.org/) 3.22+
2. Visual Studio 2022 (Desktop C++)
3. Git

```powershell
cd vst_bridge
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

VST3: `vst_bridge\build\HdlVerilator_artefacts\Release\VST3\HdlVerilator.vst3`

Скопировать в `C:\Program Files\Common Files\VST3\` и rescan plugins в DAW.

### Ubuntu

Сначала установите зависимости JUCE (один раз):

```bash
cd vst_bridge
chmod +x scripts/install_linux_deps.sh scripts/build_linux.sh
./scripts/install_linux_deps.sh
```

Или вручную:

```bash
sudo apt install -y cmake g++ git pkg-config \
  libasound2-dev libfreetype6-dev libfontconfig1-dev libcurl4-openssl-dev \
  libx11-dev libxinerama-dev libxext-dev libxcursor-dev libxrandr-dev \
  libglu1-mesa-dev libgtk-3-dev libwebkit2gtk-4.0-dev
```

Сборка (если предыдущий `cmake` падал — удалите `build/`):

```bash
rm -rf build
./scripts/build_linux.sh
```

Установка: `cp -r build/HdlVerilator_artefacts/Release/VST3/HdlVerilator.vst3 ~/.vst3/`

## E2E: Windows DAW + engine на Ubuntu/WSL2

1. **Engine** (Ubuntu или WSL2):

```bash
./scripts/run_udp_engine.sh
# или
cd verilator_tests && ./obj_dir/Vgenerator --input-source udp --output-mode udp
```

2. **Узнать IP engine:**
   - Ubuntu (отдельная машина): IP в LAN
   - WSL2: `hostname -I | awk '{print $1}'` на Linux; на Win11 с mirrored networking часто работает `127.0.0.1`

3. **VST в DAW (Windows):**
   - Загрузить `HdlVerilator` на MIDI-трек
   - В UI указать IP engine (не `127.0.0.1`, если engine в WSL2 без mirrored mode — IP WSL)
   - Порты по умолчанию: control `5004`, audio `5005`
   - Jitter buffer: 30–50 ms для начала

4. **Firewall:** разрешить UDP 5004/5005 на engine.

## E2E: Ubuntu DAW + engine (localhost)

```bash
# Терминал 1
./scripts/run_udp_engine.sh

# Терминал 2 — Reaper/Bitwig с VST3 из ~/.vst3/
# Host: 127.0.0.1
```

Без DAW — smoke-тест:

```bash
./scripts/e2e_ubuntu.sh
```

## UI

- **Engine host** — IP или hostname engine
- **Jitter buffer** — задержка буфера PCM (10–200 ms)
- **Status** — `connected` после ACK от engine
- **Buffered / warmup / Underruns** — диагностика сети и буфера

## Сборка Windows VST из WSL (cross-compile)

```bash
cd vst_bridge
./scripts/build_windows_mingw.sh          # инкрементально (~30 с)
./scripts/build_windows_mingw.sh --clean  # полная (~3–5 мин, JUCE)
```

Требуется один раз скачанный **llvm-mingw** в `vst_bridge/.toolchains/` (скрипт качает сам).

## Известные проблемы (2026-06, MVP)

E2E **работает** (MIDI → engine → PCM → DAW, ноты слышны), но с **сильной задержкой и рваным звуком**:

| Симптом | Вероятная причина | Статус |
|---------|-------------------|--------|
| Underruns растут сотнями тысяч | DirectSound / большой block size (1024) + WSL2 UDP + jitter | TODO |
| ~200 ms+ end-to-end latency | DAW buffer + jitter buffer + сеть WSL↔Win | TODO |
| Режим звуковой карты сильно влияет | ASIO vs DirectSound/WASAPI | TODO — тестировать ASIO |
| `waiting for engine ACK` при живом PCM | ACK UDP Win←WSL иногда теряется; connected ставится по PCM | workaround |

**Следующая сессия:** sample-rate lock engine↔DAW, adaptive jitter, ASIO/low-latency path, RTP-MIDI / Network MIDI 2.0 (см. todo).

## Стандарты MIDI over UDP

MVP использует проектный протокол `hdl_net`. Для совместимости с внешними инструментами в будущем:

| Стандарт | Описание |
|----------|----------|
| [RTP-MIDI RFC 6295](https://www.rfc-editor.org/rfc/rfc6295) | Де-факто стандарт (AppleMIDI, rtpMIDI) |
| [Network MIDI 2.0 UDP](https://midi.org/network-midi-2-0) | Официальная спецификация MA (2024) |

## Файлы

| Файл | Назначение |
|------|------------|
| `Source/PluginProcessor.cpp` | MIDI → NetBridge, PCM → DAW |
| `Source/NetBridge.cpp` | UDP поток, jitter buffer |
| `Source/PluginEditor.cpp` | Настройки host / jitter |
| `protocol/hdl_net.h` | Общий протокол с engine |
