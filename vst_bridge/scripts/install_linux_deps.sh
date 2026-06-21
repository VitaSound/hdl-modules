#!/usr/bin/env bash
# Ubuntu/Debian dependencies for building vst_bridge (JUCE VST3).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

declare -A PKG_PC=(
  [libfontconfig1-dev]=fontconfig
  [libgtk-3-dev]=gtk+-x11-3.0
  [libcurl4-openssl-dev]=libcurl
  [libasound2-dev]=alsa
  [libfreetype6-dev]=freetype2
)

declare -A PKG_HEADERS=(
  [libxinerama-dev]=/usr/include/X11/extensions/Xinerama.h
  [libx11-dev]=/usr/include/X11/Xlib.h
  [libxext-dev]=/usr/include/X11/extensions/Xext.h
  [libxcursor-dev]=/usr/include/X11/Xcursor/Xcursor.h
  [libxrandr-dev]=/usr/include/X11/extensions/Xrandr.h
  [libglu1-mesa-dev]=/usr/include/GL/glu.h
)

ALWAYS=(cmake g++ git pkg-config)
TO_INSTALL=()

for pkg in "${ALWAYS[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    TO_INSTALL+=("$pkg")
  fi
done

for pkg in "${!PKG_PC[@]}"; do
  if ! pkg-config --exists "${PKG_PC[$pkg]}" 2>/dev/null; then
    TO_INSTALL+=("$pkg")
  fi
done

for pkg in "${!PKG_HEADERS[@]}"; do
  if [[ ! -f "${PKG_HEADERS[$pkg]}" ]]; then
    TO_INSTALL+=("$pkg")
  fi
done

if ! pkg-config --exists webkit2gtk-4.1 2>/dev/null && \
   ! pkg-config --exists webkit2gtk-4.0 2>/dev/null; then
  if apt-cache show libwebkit2gtk-4.1-dev >/dev/null 2>&1; then
    TO_INSTALL+=(libwebkit2gtk-4.1-dev)
  else
    TO_INSTALL+=(libwebkit2gtk-4.0-dev)
  fi
fi

if ((${#TO_INSTALL[@]} > 0)); then
  mapfile -t TO_INSTALL < <(printf '%s\n' "${TO_INSTALL[@]}" | sort -u)
fi

if ((${#TO_INSTALL[@]} == 0)); then
  echo "All JUCE build dependencies are already installed."
  echo "Run: $ROOT/scripts/build_linux.sh"
  exit 0
fi

echo "Will install: ${TO_INSTALL[*]}"
sudo apt-get update
sudo apt-get install -y "${TO_INSTALL[@]}"
echo
echo "Done. Rebuild with:"
echo "  cd $ROOT && rm -rf build && ./scripts/build_linux.sh"
