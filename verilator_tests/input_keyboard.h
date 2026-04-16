#pragma once

#include <string>
#include <thread>

#include "shared_state.h"

struct KeyboardInputConfig {
    std::string devicePath = "/dev/input/event2";
};

std::thread startKeyboardInput(const KeyboardInputConfig& cfg, SharedState& state);
