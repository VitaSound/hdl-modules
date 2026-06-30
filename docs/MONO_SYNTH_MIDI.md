# mono_synth — MIDI CC и опорные точки

Справочник по [`synths/mono_synth/top.sv`](../synths/mono_synth/top.sv). Краткий обзор в [synths/mono_synth/README.md](../synths/mono_synth/README.md).

## Цепочка cutoff фильтра

```
fcut14_eff = clamp( manual + track + lfo_mod + env_mod )
           → svf_cutoff14_to_f → SVF в mono_voice
```

| Слагаемое | Источник | Формула |
|-----------|----------|---------|
| `manual` | CC74 / CC106 | 14-bit индекс на log-кривой 10 Hz…20 kHz |
| `track` | CC51 + нота | `(LUT(note) − LUT(60)) × CC51 / 128` |
| `lfo_mod` | CC49, CC50 | `(lfo_sig − 128) × CC50 / 128` (bipolar) |
| `env_mod` | CC24–27, CC28 | `adsr_filt[31:16] × CC28 / 128` (unipolar, аддитивно) |

Громкость (VCA) — **отдельный** ADSR (CC16–19) внутри `mono_voice`; на cutoff не влияет.

## Опорные точки

| Величина | Значение | Где в RTL |
|----------|----------|-----------|
| Key follow pivot | **MIDI note 60 (C4)** | `REF_NOTE` в `svf_fcut_mix` |
| Pitch bend center | **8192** (14-bit) | `reg14` init, CC121 → 8192 |
| Cutoff log range | **10 Hz … 20 kHz** @ Fs=1 MHz | `svf_cutoff14_to_f`, `note_fcut_lut` |
| Cutoff default | **fcut14 = 8192** (~447 Hz) | initial / CC121 |
| VCA ADSR default | A/D/R ≈ 7540, S = 127 | CC121 |
| Filter env default | A/D/R ≈ 7540, S = 127, **amount = 0** | CC121 |

На **C4** при любом CC51: `track = 0` → cutoff на опорной ноте = `manual + lfo_mod + env_mod` (без сдвига от клавиатуры).

## MIDI CC — полная таблица

### VCA (громкость)

| CC | Параметр | Примечание |
|----|----------|------------|
| 16 | Attack | `lin2exp_t` → rate |
| 17 | Decay | |
| 18 | Sustain | 7-bit level |
| 19 | Release | |

### Filter envelope (cutoff, независимо от VCA)

| CC | Параметр | Примечание |
|----|----------|------------|
| 24 | Filter attack | |
| 25 | Filter decay | |
| 26 | Filter sustain | |
| 27 | Filter release | |
| 28 | Filter env amount | 0 = выкл; 127 = макс. добавка к `fcut14` |

### Осциллятор

| CC / сообщение | Параметр |
|----------------|----------|
| 48 | Waveform: 0–15 saw, 16–31 square, 32–47 triangle, 48–63 sine, 64–79 ramp, 80–127 PWM |
| Pitch bend | 14-bit, центр 8192 → `note_pitch2dds` |

### Фильтр SVF

| CC | Параметр |
|----|----------|
| 74 | Cutoff MSB → `fcut14[13:7]`; без CC106 дублируется в LSB |
| 106 | Cutoff LSB → `fcut14[6:0]` |
| 71 | Resonance: `Q = 127 − CC` |
| 22 | Mode: 0–31 LP, 32–63 HP, 64–95 BP, 96–127 notch |
| 51 | Key follow amount 0…127 (0 = фикс. Hz на всех нотах) |
| 49 | LFO rate 0.1…30 Hz |
| 50 | LFO depth → cutoff (bipolar) |

### Служебные

| CC / байт | Действие |
|-----------|----------|
| 120 | All Sound Off → ADSR release (не сброс ручек) |
| 121 | Reset controllers → дефолты ADSR/wave/pitch/filter/LFO/key follow; CC74 → 8192 |
| 123 | All Notes Off |
| `0xFC` | MIDI Stop → all notes off |

CC74/106 **не** сбрасываются при VST Hello (только при CC121).

## Почему filter ADSR «не слышен»

1. **CC28 = 0 по умолчанию** — без CC28 filter env выключен. Клавиатура шлёт только ноты, не CC.
2. **Нужно явно отправить CC** (piano roll lane, automation, или smoke-тест ниже).
3. В `--midi-log` должны появляться `cc=24`…`cc=28` **до** note on.

Быстрая проверка без DAW:

```bash
make -C synths/mono_synth clean all
./synths/mono_synth/obj_dir/MonoSynth --sample-rate 44100 &
sleep 1
python3 hdl-modules-tester/scripts/udp_smoke_test.py --filter-pluck --duration 3 --wav /tmp/filter_pluck.wav
```

## Примеры

**Фиксированный фильтр:** CC51=0, automation CC74/106, CC28=0.

**Key follow:** CC51=127; на C4 слышен CC74; октавы сдвигают cutoff (~×2 на октаву при полном follow).

**Pluck:** CC28>0, CC24 быстрый attack, CC16 медленнее — фильтр открывается раньше громкости.

**1:1 cutoff = fundamental:** CC51=127, CC74=54 + CC106=124 (fcut14≈7036 = C4), CC28=0.
