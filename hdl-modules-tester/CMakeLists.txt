cmake_minimum_required(VERSION 3.22)

project(HdlModulesTester VERSION 0.4.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_program(VERILATOR verilator REQUIRED)

set(TT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(VERILATOR_MDIR "${CMAKE_BINARY_DIR}/verilator_gen")

set(ENGINE_CPP
    main.cpp
    engine.cpp
    synth_core.cpp
    net_socket.cpp
)

set(VERILATOR_CFLAGS "-I${TT_ROOT}")
set(VERILATOR_LDFLAGS "-lpthread")
set(VERILATOR_OUTPUT Vgenerator)

if(WIN32 OR CMAKE_CROSSCOMPILING)
    list(APPEND VERILATOR_CFLAGS "-D_WIN32_WINNT=0x0A00")
    set(VERILATOR_LDFLAGS "-lws2_32 -static -lpthread")
    set(VERILATOR_OUTPUT Vgenerator.exe)
endif()

set(VERILATOR_SRC_LIST "")
foreach(src IN LISTS ENGINE_CPP)
    list(APPEND VERILATOR_SRC_LIST "${TT_ROOT}/${src}")
endforeach()

set(VERILATOR_STAMP "${VERILATOR_MDIR}/.verilator_build.stamp")

add_custom_command(
    OUTPUT "${VERILATOR_STAMP}"
    COMMAND "${VERILATOR}" --cc --exe
        "${TT_ROOT}/generator.sv"
        ${VERILATOR_SRC_LIST}
        --Mdir "${VERILATOR_MDIR}"
        --top-module generator
        -CFLAGS "${VERILATOR_CFLAGS}"
        -LDFLAGS "${VERILATOR_LDFLAGS}"
        --build -j
        -o "${VERILATOR_OUTPUT}"
    WORKING_DIRECTORY "${TT_ROOT}"
    DEPENDS
        "${TT_ROOT}/generator.sv"
        ${VERILATOR_SRC_LIST}
    COMMENT "Verilator: ${VERILATOR_OUTPUT}"
    VERBATIM
)

add_custom_target(vgenerator ALL DEPENDS "${VERILATOR_STAMP}")
