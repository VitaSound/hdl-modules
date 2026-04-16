#pragma once

#include <termios.h>

class TerminalInput {
public:
    bool init();
    int readChar() const;
    ~TerminalInput();

private:
    int fd_ = -1;
    int oldFlags_ = -1;
    termios oldTerm_{};
    bool active_ = false;
};
