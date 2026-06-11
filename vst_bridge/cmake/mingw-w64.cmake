# Cross-compile VST3 for Windows x86_64 from Linux/WSL (MinGW-w64 GCC).
# Prefer llvm-mingw (build_windows_mingw.sh) — Ubuntu's mingw-w64 headers are too old for JUCE 8.
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc-posix)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++-posix)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(_HDL_MINGW_COMPAT "${CMAKE_CURRENT_LIST_DIR}/mingw_compat")
set(_HDL_MINGW_FORCE_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/mingw_forced_include.h")

# Optional: newer Direct2D/D3D headers from llvm-mingw if already downloaded.
set(_HDL_LLVM_MINGW "${CMAKE_CURRENT_LIST_DIR}/../.toolchains/llvm-mingw/x86_64-w64-mingw32/include")
set(_HDL_EXTRA_INCLUDES "")
if(EXISTS "${_HDL_LLVM_MINGW}/d2d1_3.h")
    set(_HDL_EXTRA_INCLUDES "-I\"${_HDL_LLVM_MINGW}\"")
    message(STATUS "Using extra Windows SDK headers from llvm-mingw")
else()
    message(WARNING "d2d1_3.h not found — run build_windows_mingw.sh (downloads llvm-mingw) or build will fail")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -static-libgcc -static-libstdc++ -fpermissive -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000000 -I\"${_HDL_MINGW_COMPAT}\" ${_HDL_EXTRA_INCLUDES} -include \"${_HDL_MINGW_FORCE_INCLUDE}\"")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -static-libgcc -fpermissive -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000000 -I\"${_HDL_MINGW_COMPAT}\" ${_HDL_EXTRA_INCLUDES}")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -static-libgcc -static-libstdc++")
