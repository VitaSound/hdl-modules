#!/usr/bin/env bash
# Cross-compile Vgenerator UDP engine (.exe) for Windows from Ubuntu/WSL.
# Uses the same llvm-mingw toolchain as vst_bridge.
set -euo pipefail

VT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$VT_ROOT/.." && pwd)"
VST_ROOT="$REPO_ROOT/vst_bridge"
cd "$VT_ROOT"

TOOLCHAIN_DIR="$VST_ROOT/.toolchains/llvm-mingw"
LLVM_TAR="llvm-mingw-20251216-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsje/llvm-mingw/releases/download/20251216/$LLVM_TAR"

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

OBJ_DIR=obj_dir_win
EXE="$OBJ_DIR/Vgenerator.exe"

if [[ "${1:-}" == "--clean" ]]; then
  echo "Clean rebuild: removing $OBJ_DIR"
  rm -rf "$OBJ_DIR"
fi

UDP_SOURCES=(
  main_udp.cpp
  synth_core.cpp
  input_udp.cpp
  output_udp.cpp
  net_socket.cpp
)

SECONDS=0
verilator --cc --exe generator.sv "${UDP_SOURCES[@]}" \
  --Mdir "$OBJ_DIR" \
  --top-module generator \
  -CFLAGS "-I$VT_ROOT -D_WIN32_WINNT=0x0A00 -DHDL_ENGINE_UDP_MAIN" \
  -LDFLAGS "-lws2_32 -static" \
  -o Vgenerator.exe

make -C "$OBJ_DIR" -f Vgenerator.mk \
  CXX="$CXX" AR="$AR" \
  input_udp.o main_udp.o net_socket.o output_udp.o synth_core.o verilated.o \
  Vgenerator__ALL.a

"$CXX" \
  "$OBJ_DIR/input_udp.o" \
  "$OBJ_DIR/main_udp.o" \
  "$OBJ_DIR/net_socket.o" \
  "$OBJ_DIR/output_udp.o" \
  "$OBJ_DIR/synth_core.o" \
  "$OBJ_DIR/verilated.o" \
  "$OBJ_DIR/Vgenerator__ALL.a" \
  -lws2_32 -static \
  -o "$OBJ_DIR/Vgenerator.exe"

echo "Build finished in ${SECONDS}s"
echo
echo "Windows engine: $VT_ROOT/$EXE"
echo
echo "Copy to Windows and run (cmd/PowerShell):"
echo "  Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000"
echo
echo "VST Engine host: 127.0.0.1 (same PC, no WSL NAT)"
echo "Allow UDP 5004/5005 in Windows Firewall."
