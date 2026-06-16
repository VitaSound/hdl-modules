# WSL2 + Windows DAW: сеть и рваный звук

UDP-мост **VitaSound Remote Synth** (Windows) ↔ engine (WSL) **не использует звуковой драйвер Windows** для PCM между машинами. Reaper/WASAPI влияют только на последний шаг (вывод на колонки). Рваный звук чаще всего даёт **виртуальная сеть WSL2**, а не драйвер Realtek/USB.

## Как идёт поток (протокол v2, pull)

```
Reaper (WASAPI) ← VST FIFO ← UDP :5005 ← engine (WSL)  [PCM по AudioPull]
Reaper MIDI     → VST      → UDP :5004 → engine (WSL)  [MIDI + AudioPull]
```

VST **запрашивает** PCM (`AudioPull`), engine генерирует только по запросу. Запас буфера — в пакетах (256 samples/pkt), не в ms jitter slider.

WSL2 NAT может **копить UDP-пакеты и отдавать пачками** — VST измеряет inter-arrival jitter и помечает доставку как **Bursty**. В этом режиме auto-tune **не уменьшает** reserve packets (приоритет — без разрывов звука).

## 1. WSL2 mirrored networking (рекомендуется, Win11)

Классический WSL2: engine доступен по `172.x.x.x`, PCM идёт через **Hyper-V NAT**. Это нестабильно для realtime UDP.

**Win11 22H2+** — включите mirrored mode:

Файл `%UserProfile%\.wslconfig` (Windows):

```ini
[wsl2]
networkingMode=mirrored
```

Затем в **PowerShell (админ)**:

```powershell
wsl --shutdown
```

Откройте WSL снова, запустите engine. В VST укажите **Engine host: `127.0.0.1`** (не `172.x.x.x`).

Проверка из WSL:

```bash
./scripts/run_udp_engine.sh
# в другом терминале WSL:
python3 hdl-modules-tester/scripts/udp_smoke_test.py --engine-host 127.0.0.1 --duration 2
```

## 2. Firewall Windows

VST **принимает** PCM на UDP **5005** (Windows). Engine **слушает** UDP **5004** (WSL).

PowerShell (админ), разрешить порты:

```powershell
New-NetFirewallRule -DisplayName "HDL UDP 5004" -Direction Inbound -Protocol UDP -LocalPort 5004 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "HDL UDP 5005" -Direction Inbound -Protocol UDP -LocalPort 5005 -Action Allow -ErrorAction SilentlyContinue
```

## 3. Reaper (не лечит WSL, но убирает лишнюю задержку)

| Параметр | Рекомендация |
|----------|--------------|
| Audio system | WASAPI |
| Mode | Exclusive |
| Block size | **512–1024** (не 8192) |
| Sample rate | **48000** |
| Thread priority | Time critical |

## 4. VST UI (v0.3.1 pull)

| Параметр | Рекомендация |
|----------|--------------|
| Engine host | `127.0.0.1` (mirrored) или `hostname -I` (legacy NAT); ● красный/оранжевый/зелёный |
| Network profile | **WSL** для `172.x.x.x`; **Local** для native `Vgenerator.exe` |
| Reserve packets | Auto-tune или профиль WSL/Local/LAN; слайдеры read-only в Auto |
| Play / Stop | Лампочки на кнопках; **Stop** — mute, **Play** — unmute + reconnect |
| Test note | Toggle C4; при смене profile нота переотправляется |
| Reconnect | Сброс буфера + HELLO; при успехе — auto-play |
| Reset stats | Ссылка внизу справа |

Underruns **не обнуляются сами** — старые значения не значат, что сейчас всё плохо.

## 5. Быстрая диагностика

### A. Engine жив?

В терминале WSL после запуска `./scripts/run_udp_engine.sh` при открытии VST должно быть:

```
[udp] HELLO from ... pull mode
```

### B. Изолировать WSL

Если с **mirrored + 127.0.0.1** и профилем WSL Underruns **не растут** во время ноты — проблема была в NAT.

Если **Delivery: Bursty** и Underruns растут — увеличьте target reserve или перейдите на native Windows engine.

### C. Сравнить с Linux-only

В Ubuntu/WSL без Reaper:

```bash
./scripts/e2e_ubuntu.sh
```

Если WAV чистый — RTL и engine в порядке, узкое место **Windows↔WSL UDP**.

## 6. Что обычно НЕ виновато

- **Драйвер звуковой карты** — для UDP-моста не участвует (только финальный WASAPI).
- **DirectSound vs WASAPI** — влияет на latency Reaper, не на доставку UDP из WSL.
- **Увеличение block size до 8192** — ухудшает мост (редкие большие callback'и).

## 7. Если mirrored недоступен

- Win10 / старый Win11: только `172.x.x.x` из `hostname -I`
- Профиль **WSL**, target reserve **16+** пакетов
- Закрыть VPN
- Не использовать Wi‑Fi для критичных тестов (если DAW на другой машине)

## 8. Долгосрочно

Стабильнее всего: engine **native Windows** (`hdl-modules-tester/scripts/build_windows_mingw.sh` → `Vgenerator.exe`, VST host `127.0.0.1`, профиль **Local**). Текущий MVP через WSL2 NAT требует mirrored mode или консервативные reserve packets.

## 9. Native Windows engine (рекомендуется для Reaper на том же PC)

```bash
# WSL
cd hdl-modules-tester && ./scripts/build_windows_mingw.sh
```

Скопировать `obj_dir_win/Vgenerator.exe` на Windows, запустить:

```bat
Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

VST: Engine host **`127.0.0.1`**, profile **Local**, Reaper block **512–1024**.
