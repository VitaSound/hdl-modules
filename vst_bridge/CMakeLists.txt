cmake_minimum_required(VERSION 3.22)

project(HdlVerilator VERSION 0.2.5 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG 8.0.6
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(JUCE)

include("${CMAKE_CURRENT_LIST_DIR}/cmake/cross_mingw_juce_patch.cmake")

if(CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
    add_compile_definitions(JUCE_USE_WINDOWS_MEDIA_FORMAT=0)
endif()

hdl_patch_juce_for_mingw_cross()

if(CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(_HDL_VST3_AUTO_MANIFEST FALSE)
    set(_HDL_COPY_PLUGIN FALSE)
else()
    set(_HDL_VST3_AUTO_MANIFEST TRUE)
    set(_HDL_COPY_PLUGIN TRUE)
endif()

juce_add_plugin(HdlVerilator
    COMPANY_NAME "VitaSound"
    PRODUCT_NAME "VitaSound Remote Synth"
    BUNDLE_ID com.vitasound.hdlverilator
    PLUGIN_MANUFACTURER_CODE Vtsn
    PLUGIN_CODE Hvst
    FORMATS VST3
    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE
    COPY_PLUGIN_AFTER_BUILD ${_HDL_COPY_PLUGIN}
    VST3_AUTO_MANIFEST ${_HDL_VST3_AUTO_MANIFEST}
)

juce_generate_juce_header(HdlVerilator)

target_sources(HdlVerilator
    PRIVATE
        Source/PluginProcessor.cpp
        Source/PluginEditor.cpp
        Source/NetBridge.cpp
)

target_include_directories(HdlVerilator PRIVATE protocol Source)

string(TIMESTAMP HDL_BUILD_TIMESTAMP UTC)
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/Source/BuildInfo.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/generated/BuildInfo.h"
    @ONLY
)

target_compile_definitions(HdlVerilator
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
)

target_include_directories(HdlVerilator PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/generated")

target_link_libraries(HdlVerilator
    PRIVATE
        juce::juce_audio_utils
        juce::juce_dsp
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_warning_flags
)

if(NOT CMAKE_CROSSCOMPILING AND NOT DEFINED ENV{GITHUB_ACTIONS})
    target_link_libraries(HdlVerilator PUBLIC juce::juce_recommended_lto_flags)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    include("${CMAKE_CURRENT_LIST_DIR}/cmake/mingw_win_libs.cmake")
    target_link_libraries(HdlVerilator PRIVATE ${HDL_WIN32_LIBS})
endif()

