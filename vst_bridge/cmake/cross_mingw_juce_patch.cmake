# Patches applied to JUCE when cross-compiling for Windows from Linux/WSL.

function(hdl_patch_juce_for_mingw_cross)
    if(NOT CMAKE_CROSSCOMPILING)
        return()
    endif()
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
        return()
    endif()

    set(platform_h "${juce_SOURCE_DIR}/modules/juce_core/system/juce_TargetPlatform.h")
    if(NOT EXISTS "${platform_h}")
        message(FATAL_ERROR "JUCE platform header not found: ${platform_h}")
    endif()

    file(READ "${platform_h}" _content)

    string(REPLACE
        "#ifdef __MINGW32__\n    #error \"MinGW is not supported. Please use an alternative compiler.\"\n  #endif"
        "#if 0 /* patched: Windows cross-build from Linux/WSL */\n  #endif"
        _content "${_content}")

    if(NOT _content MATCHES "patched: JUCE_64BIT for MinGW cross-build")
        string(REPLACE
            "  #ifdef _MSC_VER\n    #ifdef _WIN64\n      #define JUCE_64BIT 1\n    #else\n      #define JUCE_32BIT 1\n    #endif\n  #endif"
            "  #ifdef _MSC_VER\n    #ifdef _WIN64\n      #define JUCE_64BIT 1\n    #else\n      #define JUCE_32BIT 1\n    #endif\n  #endif\n\n  /* patched: JUCE_64BIT for MinGW cross-build */\n  #if ! defined (JUCE_64BIT) && ! defined (JUCE_32BIT)\n    #if defined (_WIN64) || defined (__x86_64__) || defined (__LP64__)\n      #define JUCE_64BIT 1\n    #else\n      #define JUCE_32BIT 1\n    #endif\n  #endif"
            _content "${_content}")
    endif()

    file(WRITE "${platform_h}" "${_content}")
    message(STATUS "Patched JUCE for Windows cross-compilation")

    set(d2d_resources "${juce_SOURCE_DIR}/modules/juce_graphics/native/juce_Direct2DResources_windows.cpp")
    if(EXISTS "${d2d_resources}")
        file(READ "${d2d_resources}" _d2d)
        string(REPLACE "__uuidof (device)" "__uuidof (IDXGIDevice)" _d2d "${_d2d}")
        string(REPLACE "__uuidof (surface)" "__uuidof (IDXGISurface)" _d2d "${_d2d}")
        file(WRITE "${d2d_resources}" "${_d2d}")
        message(STATUS "Patched JUCE Direct2D __uuidof for MinGW/clang")
    endif()

    set(audio_processor_h "${juce_SOURCE_DIR}/modules/juce_audio_processors/processors/juce_AudioProcessor.h")
    if(EXISTS "${audio_processor_h}")
        file(READ "${audio_processor_h}" _ap)
        if(NOT _ap MATCHES "patched: clang/MinGW channel layout ctor")
            string(REPLACE
                "    AudioProcessor (const std::initializer_list<const short[2]>& channelLayoutList)\n        : AudioProcessor (busesPropertiesFromLayoutArray (layoutListToArray (channelLayoutList)))\n    {\n    }"
                "    AudioProcessor (const std::initializer_list<const short[2]>& channelLayoutList)\n        : AudioProcessor (busesPropertiesFromLayoutArray (layoutListToArray (channelLayoutList)))\n    {\n    }\n\n    /* patched: clang/MinGW channel layout ctor */\n    template <size_t numLayouts>\n    AudioProcessor (const short (&channelLayoutList)[numLayouts][2])\n        : AudioProcessor (busesPropertiesFromLayoutArray (layoutListToArray (channelLayoutList)))\n    {\n    }"
                _ap "${_ap}")
            file(WRITE "${audio_processor_h}" "${_ap}")
            message(STATUS "Patched JUCE AudioProcessor channel layout ctor for MinGW/clang")
        endif()
    endif()

    set(plugin_instance_h "${juce_SOURCE_DIR}/modules/juce_audio_processors/processors/juce_AudioPluginInstance.h")
    if(EXISTS "${plugin_instance_h}")
        file(READ "${plugin_instance_h}" _pi)
        if(NOT _pi MATCHES "patched: clang/MinGW channel layout ctor")
            string(REPLACE
                "    template <size_t numLayouts>\n    AudioPluginInstance (const short channelLayoutList[numLayouts][2]) : AudioProcessor (channelLayoutList) {}"
                "    template <size_t numLayouts>\n    AudioPluginInstance (const short (&channelLayoutList)[numLayouts][2]) : AudioProcessor (channelLayoutList) {}"
                _pi "${_pi}")
            file(WRITE "${plugin_instance_h}" "${_pi}")
            message(STATUS "Patched JUCE AudioPluginInstance channel layout ctor for MinGW/clang")
        endif()
    endif()
endfunction()
