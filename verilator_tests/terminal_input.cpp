#include "terminal_input.h"

#include <fcntl.h>
#include <iostream>
#include <unistd.h>

bool TerminalInput::init() {
    fd_ = STDIN_FILENO;
    if (!isatty(fd_)) {
        std::cerr << "STDIN is not a TTY, keyboard control disabled.\n";
        return false;
    }

    if (tcgetattr(fd_, &oldTerm_) != 0) {
        perror("tcgetattr");
        return false;
    }
    termios raw = oldTerm_;
    raw.c_lflag &= static_cast<unsigned>(~(ICANON | ECHO));
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    if (tcsetattr(fd_, TCSANOW, &raw) != 0) {
        perror("tcsetattr");
        return false;
    }

    oldFlags_ = fcntl(fd_, F_GETFL, 0);
    if (oldFlags_ >= 0) {
        (void)fcntl(fd_, F_SETFL, oldFlags_ | O_NONBLOCK);
    }

    active_ = true;
    return true;
}

int TerminalInput::readChar() const {
    if (!active_) {
        return -1;
    }
    unsigned char c = 0;
    ssize_t n = ::read(fd_, &c, 1);
    if (n == 1) {
        return static_cast<int>(c);
    }
    return -1;
}

TerminalInput::~TerminalInput() {
    if (!active_) {
        return;
    }
    if (oldFlags_ >= 0) {
        (void)fcntl(fd_, F_SETFL, oldFlags_);
    }
    (void)tcsetattr(fd_, TCSANOW, &oldTerm_);
}
