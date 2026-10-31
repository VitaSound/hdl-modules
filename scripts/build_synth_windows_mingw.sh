#!/usr/bin/env bash
# Cross-compile synths/<id> UDP engine (.exe) for Windows from Ubuntu/WSL.
# Usage: ./scripts/build_synth_windows_mingw.sh <mono_synth|mini_fx|noise_box> [--clean]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VST_ROOT="$ROOT/vst_bridge"
TESTER="$ROOT/hdl-modules-tester"
ID="${1:?usage: $0 <mono_synth|mini_fx|noise_box> [--clean]}"
shift || true

case "$ID" in
  mono_synth|mini_fx|noise_box) ;;
  *)
    echo "ERROR: unknown synth id '$ID' (mono_synth|mini_fx|noise_box)" >&2
    exit 1
    ;;
esac

SYNTH_DIR="$ROOT/synths/$ID"
TOOLCHAIN_DIR="$VST_ROOT/.toolchains/llvm-mingw"
LLVM_TAR="llvm-mingw-20251216-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsje/llvm-mingw/releases/download/20251216/$LLVM_TAR"
PUBLIC_NAME="VitaSound-Engine-${ID}"
OBJ_DIR="$SYNTH_DIR/obj_dir_win"
EXE="$OBJ_DIR/${PUBLIC_NAME}.exe"

ensure_llvm_mingw() {
  if [[ -x "$TOOLCHAIN_DIR/bin/x86_64-w64-mingw32-clang++" ]]; then
    return 0
  fi
  echo "Downloading llvm-mingw (~78 MB, one-time) into vst_bridge/.toolchains/..."
  mkdir -p "$VST_ROOT/.toolchains"
  (
    cd "$VST_ROOT/.toolchains"
    curl -fsSL -o "$LLVM_TAR" "$LLVM_URL"
    rm -rf llvm-mingw
    mkdir llvm-mingw
    tar xf "$LLVM_TAR" -C llvm-mingw --strip-components=1
    rm -f "$LLVM_TAR"
  )
}

if ! command -v verilator >/dev/null; then
  echo "ERROR: verilator not found. Install: sudo apt install verilator" >&2
  exit 1
fi

ensure_llvm_mingw

MINGW_BIN="$TOOLCHAIN_DIR/bin"
export PATH="$MINGW_BIN:$PATH"
export CXX="$MINGW_BIN/x86_64-w64-mingw32-clang++"
export CC="$MINGW_BIN/x86_64-w64-mingw32-clang"
export LD="$CXX"
export AR="$MINGW_BIN/llvm-ar"

if [[ "${1:-}" == "--clean" ]]; then
  echo "Clean rebuild: removing $OBJ_DIR"
  rm -rf "$OBJ_DIR"
fi

cd "$SYNTH_DIR"

COMMON_CPP=(
  synth_core.cpp
  main.cpp
  "$TESTER/engine.cpp"
  "$TESTER/net_socket.cpp"
  "$TESTER/midi_decode.cpp"
)

case "$ID" in
  mono_synth)
    TOP=mono_synth
    RTL=(
      top.sv
      ../../io/midi_in.v
      ../../mono_voice/mono_voice.v
      ../../dds/note2dds.v
      ../../dds/note_pitch2dds.v
      ../../dds/dds.v
      ../../dds_transform/dds2saw.v
      ../../dds_transform/dds2revsaw.v
      ../../dds_transform/dds2tria.v
      ../../dds_transform/dds2square.v
      ../../dds_transform/dds2pwm.v
      ../../dds_transform/dds2sin.v
      ../../adsr/adsr.v
      ../../common/frqdivmod.v
      ../../common/strobe_gen.v
      ../../common/param_reg.v
      ../../common/reg7.v
      ../../common/reg14.v
      ../../common/note_mono.v
      ../../common/bitscan.v
      ../../common/prio_encoder.v
      ../../common/lin2exp_t.v
      ../../svf/svf.v
      ../../svf/svf_fcut_mix.v
      ../../svf/note_fcut_lut.v
      ../../lfo/lfo.v
      ../../lfo/lfo_rate_lut.v
      svf_cutoff14_to_f.v
      svf_cc_to_q.v
      ../../vca/svca16.v
      ../../vca/svca.v
    )
    VERILATOR_WARN=(-Wno-WIDTH -Wno-INITIALDLY -Wno-CASEINCOMPLETE -Wno-IMPLICIT)
    ;;
  mini_fx)
    TOP=mini_fx
    RTL=(
      top.sv
      ../../io/midi_in.v
      ../../common/reg7.v
      ../../common/param_reg.v
      ../../svf/svf.v
      svf_cutoff14_to_f.v
      svf_cc_to_q.v
    )
    VERILATOR_WARN=(-Wno-WIDTH -Wno-INITIALDLY -Wno-CASEINCOMPLETE -Wno-IMPLICIT)
    ;;
  noise_box)
    TOP=noise_box
    RTL=(top.sv ../../rnd/rndx.v)
    VERILATOR_WARN=(-Wno-WIDTH -Wno-INITIALDLY)
    ;;
esac

SECONDS=0
verilator --cc --exe "${VERILATOR_WARN[@]}" "${RTL[@]}" "${COMMON_CPP[@]}" \
  --Mdir "$OBJ_DIR" \
  --top-module "$TOP" \
  -CFLAGS "-I.. -I$TESTER -D_WIN32_WINNT=0x0A00" \
  -LDFLAGS "-lws2_32 -static" \
  -o "${PUBLIC_NAME}.exe"

# Object basenames Verilator expects for host .cpp files
OBJS=(synth_core.o main.o engine.o net_socket.o midi_decode.o verilated.o)
MK="V${TOP}.mk"
ALL_A="V${TOP}__ALL.a"

make -C "$OBJ_DIR" -f "$MK" \
  CXX="$CXX" AR="$AR" \
  "${OBJS[@]}" "$ALL_A"

"$CXX" \
  "$OBJ_DIR/synth_core.o" \
  "$OBJ_DIR/main.o" \
  "$OBJ_DIR/engine.o" \
  "$OBJ_DIR/net_socket.o" \
  "$OBJ_DIR/midi_decode.o" \
  "$OBJ_DIR/verilated.o" \
  "$OBJ_DIR/$ALL_A" \
  -lws2_32 -static \
  -o "$EXE"

echo "Build finished in ${SECONDS}s"
echo
echo "Windows engine: $EXE"
echo
echo "Run (cmd/PowerShell):"
echo "  ${PUBLIC_NAME}.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000"
echo "VST Engine host: 127.0.0.1  |  profile Local  |  DAW 48000 Hz"
