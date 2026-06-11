@echo off
REM Native Windows UDP engine (built via WSL: scripts/build_windows_mingw.sh)
setlocal
cd /d "%~dp0.."
if not exist "obj_dir_win\Vgenerator.exe" (
  echo Build first in WSL: ./verilator_tests/scripts/build_windows_mingw.sh
  exit /b 1
)
obj_dir_win\Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000 %*
