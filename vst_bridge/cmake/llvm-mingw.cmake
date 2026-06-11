# Cross-compile for Windows x86_64 using llvm-mingw (Linux host).
# Set LLVM_MINGW to unpacked toolchain root, or rely on default .toolchains/llvm-mingw.

if(NOT LLVM_MINGW)
    set(LLVM_MINGW "${CMAKE_CURRENT_LIST_DIR}/../.toolchains/llvm-mingw")
endif()

if(NOT EXISTS "${LLVM_MINGW}/bin/x86_64-w64-mingw32-clang++")
    message(FATAL_ERROR "llvm-mingw not found at ${LLVM_MINGW}. Run scripts/build_windows_mingw.sh")
endif()

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(_TRIPLET x86_64-w64-mingw32)
set(_SYSROOT "${LLVM_MINGW}/${_TRIPLET}")

set(CMAKE_C_COMPILER "${LLVM_MINGW}/bin/${_TRIPLET}-clang")
set(CMAKE_CXX_COMPILER "${LLVM_MINGW}/bin/${_TRIPLET}-clang++")
set(CMAKE_RC_COMPILER "${LLVM_MINGW}/bin/${_TRIPLET}-windres")

list(APPEND CMAKE_FIND_ROOT_PATH "${_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(_HDL_MINGW_COMPAT "${CMAKE_CURRENT_LIST_DIR}/mingw_compat")
set(_HDL_MINGW_FORCE_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/mingw_forced_include.h")

set(_HDL_WIN_FLAGS "-static -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000010 -I\"${_HDL_MINGW_COMPAT}\" -include \"${_HDL_MINGW_FORCE_INCLUDE}\"")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${_HDL_WIN_FLAGS}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -static -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000010 -I\"${_HDL_MINGW_COMPAT}\"")
