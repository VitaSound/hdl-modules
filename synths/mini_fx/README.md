# mini_fx — AudioPush test rig

Insert FX engine: **host audio in → SVF LP → host audio out**. Used to validate `hdl_net` **AudioPush** before wiring FX into `mono_synth`.

## Run

```bash
./scripts/run_mini_fx.sh
```

One engine at a time on UDP `:5004` (same as MonoSynth).

## Protocol

| Direction | Packet |
|-----------|--------|
| Host → engine | **AudioPush** (control port, HDLA-style payload) |
| Engine → host | **AudioPull** + HDLA PCM |
| Both | MIDI CC (cutoff CC74/106, resonance CC71) |

Ack advertises `kCapAudioPush`. Empty push ring → silence on pull.

## Parameters

[`mini_fx.params.yaml`](mini_fx.params.yaml) — cutoff + resonance for APVTS/panel tooling.

## VST E2E (insert)

1. `./scripts/run_mini_fx.sh`
2. Load **VST3: VitaSound Remote Synth** (effect, not VST3i) as insert on a track with material. After rebuilding the VST, Clear cache / rescan in Reaper.
3. Play — input goes **AudioPush**, wet returns via **AudioPull** (track dry is replaced, not summed).
4. Move **Filter Cutoff** (APVTS) or send CC — hear LP sweep on the same source.

## RTL

[`top.sv`](top.sv): `audio_in → SVF (tick every CLK @ 1 MHz, boxcar → AUDIO_HZ) → audio_out`, MIDI CC only (no oscillator). Cutoff/Q LUTs match `mono_synth` (`Fs=CLK_HZ`); do not tick SVF only at audio rate or the log curve collapses into the top of the slider.

Not in `modules.yaml` / `make all` (Verilator UDP engine only).
