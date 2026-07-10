# TODO

Открытые задачи и известные проблемы репозитория (не путать с чеклистом фаз в [LEGACY_MIGRATION_PLAN.md](LEGACY_MIGRATION_PLAN.md)).

Current mono_synth sprint: [`synths/mono_synth/docs/current-sprint.md`](../synths/mono_synth/docs/current-sprint.md).

---

## Common / simulation

_(пусто — `frqdivmod` odd DIV исправлен в `common/frqdivmod.v`, регрессия DIV=21 @1 MHz в `frqdivmod_test`)_

---

## mono_synth / VST

- [ ] **mono-001 Soft Hello** — на reconnect того же `plugin_ssrc` не пульсировать `rst` в `synthOnSessionStart()` ([`synths/mono_synth/synth_core.cpp`](../synths/mono_synth/synth_core.cpp)); edge case: [`EC-030`](../synths/mono_synth/docs/edge-cases.md#ec-030-reconnect-same-plugin_ssrc).
- [ ] **mono-002 VST Play** — меньше `fullReconnect` при уже живом UDP ([`vst_bridge/Source/PluginProcessor.cpp`](../vst_bridge/Source/PluginProcessor.cpp)); edge case: [`EC-031`](../synths/mono_synth/docs/edge-cases.md#ec-031-vst-play-while-udp-is-already-alive).
- [ ] **mono-003 48 kHz vs 44.1 kHz** — RTL `AUDIO_HZ=44100`; DAW/VST Hello может слать 48000; edge case: [`EC-001`](../synths/mono_synth/docs/edge-cases.md#ec-001-sample-rate-mismatch).
- [ ] **mono-004 DDS phase sync** — legato: скачок частоты без sync фазы ([`mono_voice/mono_voice.v`](../mono_voice/mono_voice.v)); edge case: [`EC-033`](../synths/mono_synth/docs/edge-cases.md#ec-033-legato-without-note-off).
- [ ] **mono-005 VCF matrix** — fc 10–15 Hz в LUT ([`tools/gen_svf_cc_lut.py`](../tools/gen_svf_cc_lut.py), [`mono_voice/test/vcf_matrix_tb.v`](../mono_voice/test/vcf_matrix_tb.v)); edge case: [`EC-024`](../synths/mono_synth/docs/edge-cases.md#ec-024-cutoff-clamp-and-low-frequency-matrix).
- [ ] **mono-006 MIDI log** — `--midi-log` не печатает sys realtime (`0xFC` Stop); DAW transport stop часто шлёт pitch center, не CC123; edge case: [`EC-032`](../synths/mono_synth/docs/edge-cases.md#ec-032-daw-transport-stop).
- [ ] **mono-007 LFO → pitch** — backlog item требует сверки с текущим RTL (`top.sv` уже передаёт VCO-LFO в `mono_voice`); edge case: [`EC-040`](../synths/mono_synth/docs/edge-cases.md#ec-040-lfo-pitch-backlog-freshness).
- [x] **mono-doc-001 Agent documentation suite** — создать [`synths/mono_synth/docs/`](../synths/mono_synth/docs/) и сократить README до index + runbook.
