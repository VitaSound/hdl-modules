#pragma once

#include <atomic>

struct SharedState {
    std::atomic<bool> running{true};
    std::atomic<bool> gate{false};
    std::atomic<int> note{-1};
};
