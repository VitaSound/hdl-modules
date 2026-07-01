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
2. Load **VitaSound Remote Synth** as insert on a track with material.
3. Play — dry goes **AudioPush**, wet returns via **AudioPull**.
4. Move **Filter Cutoff** (APVTS) or send CC — hear LP sweep on the same source.

## RTL

[`top.sv`](top.sv): `audio_in → svf → audio_out`, MIDI CC only (no oscillator).

Not in `modules.yaml` / `make all` (Verilator UDP engine only).
