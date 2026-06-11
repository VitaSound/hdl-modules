#pragma once

#ifndef _WIN32_WINNT
 #define _WIN32_WINNT 0x0A00
#endif
#ifndef NTDDI_VERSION
 #define NTDDI_VERSION 0x0A000010
#endif
#ifndef WINAPI_FAMILY
 #define WINAPI_FAMILY WINAPI_FAMILY_DESKTOP_APP
#endif

#include <sdkddkver.h>

/* MinGW headers omit CaretPosition (used by JUCE 8 UIAutomation). */
#ifndef CaretPosition_BeginningOfLine
typedef enum CaretPosition {
    CaretPosition_Unknown = 0,
    CaretPosition_EndOfLine = 1,
    CaretPosition_BeginningOfLine = 2
} CaretPosition;
#endif
