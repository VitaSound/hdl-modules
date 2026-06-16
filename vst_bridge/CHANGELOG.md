# Changelog — VitaSound Remote Synth

Формат версий: [Semantic Versioning](https://semver.org/). Тег релиза репозитория: `vX.Y.Z` (файл [`VERSION`](../VERSION), VST — `CMakeLists.txt`).

## [0.4.0] — 2026-06-16

### Репозиторий

- Разделение: **`hdl-modules-tester`** (UDP pull-only) и **`verilator_tests`** (legacy local).
- Единый GitHub Release `v0.4.0`: VST3 (Linux/Windows) + оба engine-бинарника.

### VST 0.4.0

- Без изменений протокола относительно 0.3.1; engine-пути обновлены на `hdl-modules-tester/`.

## [0.3.1] — 2026-06-16

### Протокол и engine (pull v2)

- UDP **protocol v2**: `AudioPull`, расширенный `Hello`/`Ack`, `kSessionModePull`.
- Engine генерирует PCM **только по запросу** (`input_udp`); `output_udp` — заглушка.
- Синхронизация `hdl_net.h` между `vst_bridge/` и `hdl-modules-tester/`.

### VST: сеть и буфер

- Pull-scheduler в `NetBridge`: reserve packets, без jitter/trim.
- `DeliveryQualityMonitor`: jitter, burst detection, профили **Auto / WSL / Local / LAN**.
- Auto-tune буферов (асимметричный: быстрый рост / медленное снижение).
- **Auto-reconnect**: Hello каждые 500 ms при обрыве, таймаут активности 3 s.
- **Auto-play** при восстановлении соединения; Stop сбрасывает авто-возобновление.
- Auto-tune и pull **не работают в режиме Stop** (muted).

### UI

- Версия **0.3.1** + git hash в build id (`BuildInfo.h`).
- Buffer progress bar (fill / target / min marker).
- Панельные кнопки **Test note / Play / Stop** с лампочками (зелёная / красная).
- Индикатор соединения у поля Engine host; **Reconnect** справа от IP.
- Двухстрочная статистика; **Reset stats** — текстовая ссылка.
- Auto-профиль: read-only слайдеры, значения от bridge / auto-tune.
- Test note: повторный NoteOn после смены network profile (Hello сбрасывает gate на engine).

### Сборка

- Git hash в `HDL_VERILATOR_BUILD_ID` при cmake configure.
- Патч JUCE для llvm-mingw (Clang 21).

### Документация

- Обновлены `vst_bridge/README.md`, `docs/WSL_NETWORKING.md`, скриншот UI (`docs/ui.png`).

## [0.2.5] — ранее

- Переименование в **VitaSound Remote Synth**, GitHub release workflow, cross-build Windows из WSL.

[0.4.0]: https://github.com/VitaSound/hdl-modules/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/UA3MQJ/hdl-modules/compare/vst-v0.2.5...vst-v0.3.1
