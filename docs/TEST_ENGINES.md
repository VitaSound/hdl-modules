# Проверка трёх ядер (noise / mono / FX)

Sample rate везде **48000**. На UDP `:5004` — только один engine. Перед сменой ядра закройте предыдущий процесс.

Публичные имена: [`ENGINES.md`](ENGINES.md). Модель VST: **VitaSound Remote** (effect).

## Один раз: DAW + VST

1. Reaper или FL: project / audio **48000 Hz**, buffer **512–1024**.
2. Плагин: **VST3: VitaSound Remote**.
   - Путь: `C:\Users\Admin\VitaSound\VST3` (добавить в VST paths) **или** `C:\Program Files\Common Files\VST3\`.
   - Rescan plugins.
3. Engines на Windows: `C:\Users\Admin\VitaSound\VitaSound-Engine-*.exe`.
4. В UI Remote: Engine host **`127.0.0.1`**, Network profile **Local** (native `.exe`) или **WSL**, кнопка **Play**.
5. Status должен содержать `engine <id>` (из schema).

WSL-альтернатива любому шагу ниже: `./scripts/run_<id>.sh` из корня репо (mirrored networking → host `127.0.0.1`).

---

## A. Шум — `noise_box`

```bat
cd C:\Users\Admin\VitaSound
VitaSound-Engine-noise_box.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

Или WSL: `./scripts/run_noise_box.sh`

| Шаг | Ожидание |
|-----|----------|
| MIDI-трек → VitaSound Remote → Play → **Test note** / любая нота | Белый шум, пока нота держится |
| Note Off | Тишина |
| Параметры в UI | Почти нет (только gate) — нормально |

---

## B. Синт — `mono_synth`

Остановите `noise_box`, затем:

```bat
VitaSound-Engine-mono_synth.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

Или WSL: `./scripts/run_mono_synth.sh`

| Шаг | Ожидание |
|-----|----------|
| Play → Test note / piano roll | Тон с ADSR |
| Status | `engine mono_synth` |
| VCA Attack / Release, Waveform, Filter Cutoff/Res, Filter env | Слышны изменения |
| DAW = 48000 | Pitch не «плывёт» (на 44100 будет криво) |

CC-справка: [`MONO_SYNTH_MIDI.md`](MONO_SYNTH_MIDI.md).

---

## C. FX — `mini_fx`

Остановите mono, затем:

```bat
VitaSound-Engine-mini_fx.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

Или WSL: `./scripts/run_mini_fx.sh`

| Шаг | Ожидание |
|-----|----------|
| **Аудио-трек** с wav/loop → insert VitaSound Remote | Не пустой MIDI-only трек |
| Play транспорта DAW | Слышен обработанный вход (LP) |
| Filter Cutoff / Resonance в UI | Меняется тембр источника |
| Нет входного звука | Тишина (так и должно быть у FX) |

---

## Smoke без DAW (WSL, опционально)

```bash
./scripts/e2e_mono_synth.sh

fuser -k 5004/udp 2>/dev/null || true
./scripts/run_noise_box.sh &
sleep 1
python3 hdl-modules-tester/scripts/udp_smoke_test.py --duration 2
```

---

## Если не работает

| Симптом | Что проверить |
|---------|----------------|
| Status waiting / красный | Engine запущен? Порт 5004 свободен? Firewall UDP 5004/5005? |
| Тишина на synth | Play нажат? Test note / MIDI? Sample rate 48000? |
| Тишина на FX | Есть audio на треке? Insert Remote на **аудио**-трек? |
| Underruns / рваный звук | Profile Local + native `.exe`, buffer 512–1024; WSL → mirrored networking |

После успешной проверки трёх ядер можно планировать видео-презентацию.
