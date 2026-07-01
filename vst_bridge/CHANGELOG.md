# Changelog — VitaSound Remote Synth

Формат версий: [Semantic Versioning](https://semver.org/). Тег релиза репозитория: `vX.Y.Z` (файл [`VERSION`](../VERSION), VST — `CMakeLists.txt`).

## [0.7.0] — 2026-07-02

### Runtime параметры

- Wire-протокол **hdl_net v5**: добавлены `ParamSchemaRequest` / `ParamSchemaData`.
- Engine читает `*.params.yaml` при старте и отдаёт schema параметров VST.
- VST строит named APVTS параметры из server schema, а при недоступном engine использует локальный cache последней schema.
- Убран compile-time APVTS generation из сборки VST: YAML-only изменения параметров больше не требуют пересборки VST, но требуют reload/rescan instance в DAW.

## [0.6.0] — 2026-07-02

### MonoSynth параметры

- Исправлен mapping choice-параметров через явные `midi_values`: waveform и filter mode теперь отправляют CC-значения, которые ожидает RTL.
- Добавлен **PWM Duty** (CC57) для формы PWM.
- LFO расширен выбором формы: sine, triangle, saw, ramp, square.
- Добавлены отдельные **VCO-LFO** (pitch), **VCA-LFO2** (tremolo) и **VCF-LFO3** (cutoff).
- APVTS и CtrlrX panel генерируются из обновлённого `mono_synth.params.yaml`.

## [0.5.0] — 2026-06-30

### Протокол hdl_net v4

- Версия wire-протокола **3 → 4** (несовместимо с v3: строгая проверка `version` в заголовке).
- **AudioPush**: host → engine (stereo int16, payload как HDLA).
- **Ack `kCapAudioPush`**: engine объявляет поддержку push (MiniFX).

### VST 0.5.0

- **Stereo input** bus для insert/FX path.
- **NetBridge**: отправка AudioPush при `kCapAudioPush`; приём PCM по pull без изменений.
- **APVTS**: именованные параметры mono_synth из `mono_synth.params.yaml` → MIDI CC → engine.
- UI: **GenericAudioProcessorEditor** (параметры) + существующая панель Network/transport.
- State/presets: APVTS + network settings в project state.

### Engine / mini_fx

- `synths/mini_fx/`: insert SVF (`audio_in → filter → audio_out`), `scripts/run_mini_fx.sh`.
- Smoke: `hdl-modules-tester/scripts/mini_fx_smoke_test.py`.

### Tooling

- `tools/validate_synth_params.py`, `tools/gen_vst_apvts.py`, `tools/gen_ctrlrx_panel.py`.
- `docs/CTRLRX_PANEL.md`, `synths/mini_fx/README.md`.

**Совместимость:** VST **0.5.0** требует engine с **hdl_net v4**. Pull-only с MonoSynth/NoiseBox на v4 — OK; VST **0.4.x** с engine v4 — **не** подключится.

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

[0.5.0]: https://github.com/VitaSound/hdl-modules/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/VitaSound/hdl-modules/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/UA3MQJ/hdl-modules/compare/vst-v0.2.5...vst-v0.3.1
