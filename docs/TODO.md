# TODO

Открытые задачи и известные проблемы репозитория (не путать с чеклистом фаз в [LEGACY_MIGRATION_PLAN.md](LEGACY_MIGRATION_PLAN.md)).

---

## Common / simulation

_(пусто — `frqdivmod` odd DIV исправлен в `common/frqdivmod.v`, регрессия DIV=21 @1 MHz в `frqdivmod_test`)_

---

## mono_synth / VST

- **Soft Hello** — на reconnect того же `plugin_ssrc` не пульсировать `rst` в `synthOnSessionStart()` ([`synths/mono_synth/synth_core.cpp`](../synths/mono_synth/synth_core.cpp)).
- **VST Play** — меньше `fullReconnect` при уже живом UDP ([`vst_bridge/Source/PluginProcessor.cpp`](../vst_bridge/Source/PluginProcessor.cpp)).
- **48 kHz vs 44.1 kHz** — RTL `AUDIO_HZ=44100`; DAW/VST Hello может слать 48000.
- **DDS phase sync** — legato: скачок частоты без sync фазы ([`mono_voice/mono_voice.v`](../mono_voice/mono_voice.v)).
- **VCF matrix** — fc 10–15 Hz в LUT ([`tools/gen_svf_cc_lut.py`](../tools/gen_svf_cc_lut.py), [`mono_voice/test/vcf_matrix_tb.v`](../mono_voice/test/vcf_matrix_tb.v)).
- **MIDI log** — `--midi-log` не печатает sys realtime (`0xFC` Stop); DAW transport stop часто шлёт pitch center, не CC123.
- **LFO → pitch** — отдельный CC depth на `note_pitch2dds` (сейчас LFO только на filter).
