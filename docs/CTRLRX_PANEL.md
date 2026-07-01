# CtrlrX panel for mono_synth

Machine-readable parameters live in [`synths/mono_synth/mono_synth.params.yaml`](../synths/mono_synth/mono_synth.params.yaml). The panel is generated — do not edit by hand.

## Regenerate

```bash
python3 tools/gen_ctrlrx_panel.py
python3 tools/validate_synth_params.py
```

Output: [`synths/mono_synth/panels/mono_synth.panel`](../synths/mono_synth/panels/mono_synth.panel)

## FL Studio (Patcher)

1. Install [CtrlrX](https://github.com/damiensellier/CtrlrX) VST.
2. Patcher chain: **CtrlrX (mono_synth.panel) → VitaSound Remote Synth**.
3. Panel option `panelMidiOutputToHost="1"` sends MIDI CC to VitaSound; VitaSound forwards CC to the UDP engine.
4. VitaSound APVTS parameters (automation/presets) send the same CC in parallel — dual path is OK.

## Cutoff (14-bit)

Panel slider `filter_cutoff` uses Lua to emit **CC74 + CC106** on each change (same as APVTS in VitaSound).

## MIDI reference

See [`docs/MONO_SYNTH_MIDI.md`](MONO_SYNTH_MIDI.md).
