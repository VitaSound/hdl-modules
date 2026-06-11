cmake_minimum_required(VERSION 3.22)

project(VgeneratorEngine VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(HDL_ENGINE_UDP_ONLY "Build UDP bridge engine only (no PortAudio/evdev/ALSA)" OFF)

find_program(VERILATOR verilator REQUIRED)

set(VT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(VERILATOR_MDIR "${CMAKE_BINARY_DIR}/verilator_gen")

if(HDL_ENGINE_UDP_ONLY)
    set(ENGINE_CPP
        main_udp.cpp
        synth_core.cpp
        input_udp.cpp
        output_udp.cpp
        net_socket.cpp
    )
    set(VERILATOR_CFLAGS "-I${VT_ROOT} -DHDL_ENGINE_UDP_MAIN")
    if(WIN32 OR CMAKE_CROSSCOMPILING)
        list(APPEND VERILATOR_CFLAGS "-D_WIN32_WINNT=0x0A00")
        set(VERILATOR_LDFLAGS "-lws2_32 -static -lpthread")
    else()
        set(VERILATOR_LDFLAGS "-lpthread")
    endif()
    set(VERILATOR_OUTPUT Vgenerator.exe)
else()
    set(ENGINE_CPP
        main.cpp
        synth_core.cpp
        terminal_input.cpp
        input_keyboard.cpp
        input_midi.cpp
        input_udp.cpp
        output_soundcard.cpp
        output_udp.cpp
        output_wav.cpp
        net_socket.cpp
    )
    set(VERILATOR_CFLAGS "-I${VT_ROOT}")
    set(VERILATOR_LDFLAGS "-lportaudio -lasound -lpthread")
    set(VERILATOR_OUTPUT Vgenerator)
endif()

set(VERILATOR_SRC_LIST "")
foreach(src IN LISTS ENGINE_CPP)
    list(APPEND VERILATOR_SRC_LIST "${VT_ROOT}/${src}")
endforeach()

set(VERILATOR_STAMP "${VERILATOR_MDIR}/.verilator_build.stamp")

add_custom_command(
    OUTPUT "${VERILATOR_STAMP}"
    COMMAND "${VERILATOR}" --cc --exe
        "${VT_ROOT}/generator.sv"
        ${VERILATOR_SRC_LIST}
        --Mdir "${VERILATOR_MDIR}"
        --top-module generator
        -CFLAGS "${VERILATOR_CFLAGS}"
        -LDFLAGS "${VERILATOR_LDFLAGS}"
        --build -j
        -o "${VERILATOR_OUTPUT}"
    WORKING_DIRECTORY "${VT_ROOT}"
    DEPENDS
        "${VT_ROOT}/generator.sv"
        ${VERILATOR_SRC_LIST}
    COMMENT "Verilator: ${VERILATOR_OUTPUT}"
    VERBATIM
)

add_custom_target(vgenerator ALL DEPENDS "${VERILATOR_STAMP}")

message(STATUS "Vgenerator engine: HDL_ENGINE_UDP_ONLY=${HDL_ENGINE_UDP_ONLY}")
