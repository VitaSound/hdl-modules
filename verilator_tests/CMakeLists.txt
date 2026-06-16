cmake_minimum_required(VERSION 3.22)

project(VgeneratorLegacy VERSION 0.4.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_program(VERILATOR verilator REQUIRED)

set(VT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(VERILATOR_MDIR "${CMAKE_BINARY_DIR}/verilator_gen")

set(ENGINE_CPP
    main.cpp
    synth_core.cpp
    terminal_input.cpp
    input_keyboard.cpp
    input_midi.cpp
    output_soundcard.cpp
    output_wav.cpp
)

set(VERILATOR_CFLAGS "-I${VT_ROOT}")
set(VERILATOR_LDFLAGS "-lportaudio -lasound -lpthread")
set(VERILATOR_OUTPUT Vgenerator)

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
