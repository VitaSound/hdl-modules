# mono_synth edge cases

Happy path: DAW at 44100 Hz -> VST Play -> one engine on UDP `:5004` -> MIDI note -> audible sound with ADSR. Everything else is checked here.

This file is not a duplicate of `TODO.md`. It describes expected behavior outside the happy path. Backlog items (`mono-00x`) point to these cases.

## Case Template

```markdown
### EC-xxx: short name
- category: errors | empty | validation | atypical | failure
- trigger: what starts the case
- layers: RTL | engine | VST | network
- current_behavior: what happens now
- expected_behavior: target behavior
- code: related paths
- task: mono-00x or —
- test: how to reproduce
```

## 1. Ошибки

### EC-001: sample rate mismatch
- category: errors
- trigger: VST `HelloPayload.sample_rate` is `48000`, while RTL uses `AUDIO_HZ=44100`
- layers: RTL, engine, VST
- current_behavior: timing/pitch can mismatch because RTL audio tick is fixed
- expected_behavior: engine/VST either agree on 44100 or handle/resample/reject mismatch explicitly
- code: `../top.sv`, `../synth_core.cpp`, `../../../vst_bridge/`
- task: `mono-003`
- test: run engine at 44100, open DAW project at 48000, inspect Hello log and audio timing

### EC-002: protocol version mismatch
- category: errors
- trigger: VST and engine use different `hdl_net` versions
- layers: engine, VST, network
- current_behavior: packets should fail strict header/version checks
- expected_behavior: no undefined parsing; logs should make version mismatch clear
- code: `../../../hdl-modules-tester/protocol/hdl_net.h`, `../../../vst_bridge/protocol/hdl_net.h`
- task: —
- test: run mismatched VST/engine builds and verify no connection is accepted

### EC-003: second engine on port 5004
- category: errors
- trigger: user starts another UDP engine while one is already bound to `:5004`
- layers: engine, network
- current_behavior: bind should fail for the second engine
- expected_behavior: clear error; no silent connection to the wrong synth
- code: `../../../hdl-modules-tester/net_socket.cpp`, `../main.cpp`
- task: —
- test: start two engines with default bind address

### EC-004: engine not running
- category: errors
- trigger: user presses VST Play with no engine listening
- layers: VST, network
- current_behavior: VST retries Hello / reconnect path
- expected_behavior: VST stays stable, does not invent params, and UI clearly shows disconnected state
- code: `../../../vst_bridge/Source/PluginProcessor.cpp`
- task: `mono-002`
- test: open VST with no engine, press Play, watch status and logs

### EC-005: stale Verilator build
- category: errors
- trigger: RTL or C++ changed but `obj_dir/MonoSynth` was not rebuilt
- layers: engine, RTL
- current_behavior: user may run old behavior
- expected_behavior: docs and sprint should require rebuild for behavior checks
- code: `../Makefile`, `../obj_dir/`
- task: —
- test: modify RTL, skip `make -C synths/mono_synth`, compare binary timestamp

## 2. Пустые Состояния

### EC-010: no notes / gate off
- category: empty
- trigger: no active MIDI note or all notes off
- layers: RTL
- current_behavior: `note_mono` deasserts `gate`
- expected_behavior: silence or ADSR release tail; no SVF runaway, DC runaway, or stuck gate
- code: `../top.sv`, `../../../common/note_mono.v`, `../../../mono_voice/mono_voice.v`
- task: —
- test: send note on/off and wait beyond release

### EC-011: CC121 reset controllers
- category: empty
- trigger: MIDI CC121
- layers: RTL
- current_behavior: resets controller defaults in `top.sv`
- expected_behavior: pitch center 8192, ADSR defaults, filter defaults, LFO depths 0, PWM duty 64, cutoff 8192
- code: `../top.sv`
- task: —
- test: send CC changes, then CC121, then inspect audio/log behavior

### EC-012: filter envelope amount is zero
- category: empty
- trigger: CC28 default or set to 0
- layers: RTL
- current_behavior: filter envelope ADSR runs, but does not modulate cutoff
- expected_behavior: no audible filter envelope until CC28 > 0
- code: `../top.sv`, `../../../docs/MONO_SYNTH_MIDI.md`
- task: —
- test: compare long note with CC28=0 and CC28>0

### EC-013: LFO depth is zero
- category: empty
- trigger: VCO/VCA/VCF LFO rate/shape set, depth remains 0
- layers: RTL
- current_behavior: LFO signal exists but modulation depth is zero
- expected_behavior: no pitch/tremolo/cutoff modulation
- code: `../top.sv`, `../../../lfo/lfo.v`
- task: —
- test: set rate/shape only; compare with depth > 0

### EC-014: empty MIDI queue on session start
- category: empty
- trigger: new Hello/session with no pending MIDI
- layers: engine, RTL
- current_behavior: engine drains queue and pulses reset
- expected_behavior: no crash; output starts from deterministic silent/default state
- code: `../synth_core.cpp`
- task: `mono-001`
- test: connect VST without notes, observe startup

## 3. Валидация

### EC-020: CC74 without CC106
- category: validation
- trigger: host sends cutoff MSB only
- layers: RTL
- current_behavior: `fcut14[13:7]` and `fcut14[6:0]` both receive `msb`
- expected_behavior: 7-bit knob covers full cutoff range without requiring fine CC
- code: `../top.sv`
- task: —
- test: automate CC74 only and listen to full sweep

### EC-021: CC106 after CC74
- category: validation
- trigger: host sends cutoff LSB after MSB
- layers: RTL
- current_behavior: `fcut14[6:0]` is overwritten by CC106
- expected_behavior: fine cutoff adjustment works without changing MSB
- code: `../top.sv`
- task: —
- test: send CC74 fixed, sweep CC106

### EC-022: resonance inversion
- category: validation
- trigger: CC71 resonance changes
- layers: RTL
- current_behavior: `fres_cc = 127 - fres7`
- expected_behavior: UI semantics and RTL Q mapping stay consistent
- code: `../top.sv`, `../svf_cc_to_q.v`
- task: —
- test: sweep CC71 and compare resonance direction

### EC-023: params choice values
- category: validation
- trigger: VST sends choice parameters for waveform, mode, LFO shape
- layers: params, VST, RTL
- current_behavior: `midi_values` map UI choices to high-bit CC ranges
- expected_behavior: VST sends values expected by `top.sv` high-bit decode
- code: `../mono_synth.params.yaml`, `../top.sv`
- task: —
- test: select each waveform/mode and verify audible/RTL behavior

### EC-024: cutoff clamp and low-frequency matrix
- category: validation
- trigger: cutoff mix reaches low end around 10-15 Hz
- layers: RTL
- current_behavior: known backlog item around VCF matrix and LUT low end
- expected_behavior: cutoff stays in valid range and matrix tests agree with LUT
- code: `../../../tools/gen_svf_cc_lut.py`, `../../../mono_voice/test/vcf_matrix_tb.v`
- task: `mono-005`
- test: run the VCF matrix test and low-frequency cases

## 4. Нетипичные Действия Пользователя

### EC-030: reconnect same plugin_ssrc
- category: atypical
- trigger: same VST instance reconnects
- layers: engine, RTL, VST
- current_behavior: `synthOnSessionStart()` pulses `rst`
- expected_behavior: reconnect of the same `plugin_ssrc` should not unnecessarily reset synth state if UDP is alive
- code: `../synth_core.cpp`, `../../../vst_bridge/Source/PluginProcessor.cpp`
- task: `mono-001`
- test: reconnect same VST instance and listen for click/state reset

### EC-031: VST Play while UDP is already alive
- category: atypical
- trigger: user presses Play when bridge already has a healthy UDP session
- layers: VST, engine
- current_behavior: backlog says too many `fullReconnect` paths
- expected_behavior: avoid unnecessary reconnect; preserve active session when safe
- code: `../../../vst_bridge/Source/PluginProcessor.cpp`
- task: `mono-002`
- test: press Play repeatedly while engine is alive

### EC-032: DAW transport Stop
- category: atypical
- trigger: DAW sends sys realtime Stop `0xFC`
- layers: MIDI, RTL, engine
- current_behavior: RTL maps `0xFC` to all-notes-off path, but `--midi-log` may not print it
- expected_behavior: gate releases and debug log shows the event when MIDI logging is enabled
- code: `../top.sv`, `../synth_core.cpp`, `../../../hdl-modules-tester/midi_decode.cpp`
- task: `mono-006`
- test: press DAW transport stop with `--midi-log`

### EC-033: legato without note off
- category: atypical
- trigger: new note arrives while previous note is still held
- layers: RTL
- current_behavior: `note_mono` selects active note; DDS phase may jump
- expected_behavior: documented phase behavior; if fixed, no audible unexpected discontinuity
- code: `../../../common/note_mono.v`, `../../../mono_voice/mono_voice.v`
- task: `mono-004`
- test: play overlapping notes and inspect/listen for discontinuity

### EC-034: mixed Test Note and piano roll
- category: atypical
- trigger: VST Test note and DAW piano roll notes overlap
- layers: VST, MIDI, RTL
- current_behavior: both generate MIDI note stream into `note_mono`
- expected_behavior: highest-note/gate behavior remains deterministic; no stuck note
- code: `../../../vst_bridge/`, `../../../common/note_mono.v`
- task: —
- test: toggle Test note while playing piano roll

## 5. Ошибки И Сбои

### EC-040: LFO pitch backlog freshness
- category: failure
- trigger: task `mono-007` is selected for implementation
- layers: RTL
- current_behavior: backlog still says LFO is only on filter, while current `top.sv` passes `vco_lfo_sig`, `vco_lfo_depth7`, and `vco_lfo_fine7` into `mono_voice`
- expected_behavior: before coding, verify current wiring from `top.sv` through `mono_voice` into `note_pitch2dds`; update backlog/docs instead of adding duplicate wiring if already done
- code: `../top.sv`, `../../../mono_voice/mono_voice.v`, `../../../dds/note_pitch2dds.v`
- task: `mono-007`
- test: inspect RTL wiring and send CC53-56 while holding a note

| id | Case | Status | Expected result |
|----|------|--------|-----------------|
| `mono-001` | EC-030 Soft Hello / same `plugin_ssrc` reconnect | open | No needless `rst` pulse on same healthy session |
| `mono-002` | EC-031 VST Play fullReconnect | open | Fewer reconnects when UDP is already alive |
| `mono-003` | EC-001 48 kHz vs 44.1 kHz | open | Explicit handling of sample-rate mismatch |
| `mono-004` | EC-033 DDS phase sync on legato | open | Defined or improved phase behavior |
| `mono-005` | EC-024 VCF matrix low-frequency LUT | open | Correct low-frequency cutoff behavior |
| `mono-006` | EC-032 MIDI log misses `0xFC` | open | `--midi-log` shows sys realtime Stop |
| `mono-007` | EC-040 LFO -> pitch backlog check | needs-check | Before coding, compare `../top.sv` -> `../../../mono_voice/mono_voice.v` -> `note_pitch2dds` wiring |

Additional infrastructure failures: WSL networking, firewall, and host address issues belong to [`../../../docs/WSL_NETWORKING.md`](../../../docs/WSL_NETWORKING.md).

## Related Docs

- [`schema.md`](schema.md) — happy-path contracts that these cases violate or stress.
- [`architecture.md`](architecture.md) — layer ownership and file-placement rules.
- [`../../../docs/TODO.md`](../../../docs/TODO.md) — backlog ids and status.
- [`current-sprint.md`](current-sprint.md) — active work context.
