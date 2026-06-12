# WSL2 + Windows DAW: сеть и рваный звук

UDP-мост **VitaSound Remote Synth** (Windows) ↔ engine (WSL) **не использует звуковой драйвер Windows** для PCM между машинами. Reaper/WASAPI влияют только на последний шаг (вывод на колонки). Рваный звук чаще всего даёт **виртуальная сеть WSL2**, а не драйвер Realtek/USB.

## Как идёт поток

```
Reaper (WASAPI) ← VST FIFO ← UDP :5005 ← engine (WSL)
Reaper MIDI     → VST      → UDP :5004 → engine (WSL)
```

PCM ~48 000 int16/s ≈ **94 UDP-пакета/с** (256 samples каждые ~5.3 ms). WSL2 NAT может **копить пакеты и отдавать пачками** — отсюда периодические провалы (~2 раза/с), даже при большом jitter buffer.

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
python3 verilator_tests/scripts/udp_smoke_test.py --engine-host 127.0.0.1 --duration 2
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

## 4. VST UI

| Параметр | Рекомендация |
|----------|--------------|
| Engine host | `127.0.0.1` (mirrored) или `hostname -I` (legacy NAT) |
| Jitter | **100–150 ms** для WSL2 NAT; **80 ms** для mirrored/localhost |
| Stop / Play | **Stop = mute** (звука нет). После Stop нажмите **Play** |
| Reset stats | Обнуляет Underruns перед проверкой |

Underruns **не обнуляются сами** — старые 50000+ не значат, что сейчас всё плохо.

## 5. Быстрая диагностика

### A. Engine жив?

В терминале WSL после запуска `./scripts/run_udp_engine.sh` при открытии VST должно быть:

```
[udp] HELLO from ...
```

### B. Изолировать WSL

Если с **mirrored + 127.0.0.1** и jitter 100 ms Underruns **не растут** во время ноты — проблема была в NAT.

Если **всё равно растут** — возможна нагрузка CPU на Verilator (редко при одном голосе).

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
- Jitter **150–200 ms**
- Закрыть VPN
- Не использовать Wi‑Fi для критичных тестов (если DAW на другой машине)

## 8. Долгосрочно

Стабильнее всего: engine **native Windows** (`verilator_tests/scripts/build_windows_mingw.sh` → `Vgenerator.exe`, VST host `127.0.0.1`) или engine на **другом PC в LAN**. Текущий MVP через WSL2 NAT требует mirrored mode или большой jitter.

## 9. Native Windows engine (рекомендуется для Reaper на том же PC)

```bash
# WSL
cd verilator_tests && ./scripts/build_windows_mingw.sh
```

Скопировать `obj_dir_win/Vgenerator.exe` на Windows, запустить:

```bat
Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000
```

VST: Engine host **`127.0.0.1`**, jitter **80 ms**, Reaper block **512–1024**.
