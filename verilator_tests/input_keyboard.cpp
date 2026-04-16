#include "input_keyboard.h"

#include <chrono>
#include <bitset>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

namespace {
#define BITS_PER_LONG (sizeof(unsigned long) * 8)
#define NBITS(x) ((((x) - 1) / BITS_PER_LONG) + 1)
#define TEST_BIT(array, bit) ((array[(bit) / BITS_PER_LONG] >> ((bit) % BITS_PER_LONG)) & 1UL)

int keyToScaleIndex(uint16_t code) {
    switch (code) {
        case KEY_Q: return 0;  // C
        case KEY_2: return 1;  // C#
        case KEY_W: return 2;  // D
        case KEY_3: return 3;  // D#
        case KEY_E: return 4;  // E
        case KEY_R: return 5;  // F
        case KEY_5: return 6;  // F#
        case KEY_T: return 7;  // G
        case KEY_6: return 8;  // G#
        case KEY_Y: return 9;  // A
        case KEY_7: return 10; // A#
        case KEY_U: return 11; // B
        default: return -1;
    }
}

constexpr int kKeyboardNotes[12] = {
    48, // C3
    49, // C#3
    50, // D3
    51, // D#3
    52, // E3
    53, // F3
    54, // F#3
    55, // G3
    56, // G#3
    57, // A3
    58, // A#3
    59  // B3
};

constexpr uint16_t kScaleKeyCodes[12] = {
    KEY_Q, KEY_2, KEY_W, KEY_3, KEY_E, KEY_R, KEY_5, KEY_T, KEY_6, KEY_Y, KEY_7, KEY_U
};

int noteFromScaleIndex(int idx) {
    if (idx < 0 || idx >= 12) {
        return -1;
    }
    return kKeyboardNotes[idx];
}

void printKeyDebug(bool gate, int note, int velocity) {
    std::cerr << "[keyboard] GATE " << (gate ? "ON" : "OFF")
              << " | NOTE " << note
              << " | VELOCITY " << velocity << "\n";
    std::cerr.flush();
}

std::bitset<128> readPressedBitsFromKernel(int fd) {
    std::bitset<128> bits;
    unsigned long keyBits[NBITS(KEY_MAX + 1)]{};
    if (ioctl(fd, EVIOCGKEY(sizeof(keyBits)), keyBits) < 0) {
        return bits;
    }

    for (int i = 0; i < 12; ++i) {
        if (TEST_BIT(keyBits, kScaleKeyCodes[i])) {
            const int note = noteFromScaleIndex(i);
            if (note >= 0 && note < 128) {
                bits.set(static_cast<size_t>(note));
            }
        }
    }
    return bits;
}
} // namespace

std::thread startKeyboardInput(const KeyboardInputConfig& cfg, SharedState& state) {
    return std::thread([cfg, &state]() {
        int fd = open(cfg.devicePath.c_str(), O_RDONLY | O_NONBLOCK);
        if (fd < 0) {
            std::cerr << "Cannot open input device " << cfg.devicePath
                      << " (need read permission): " << strerror(errno) << "\n";
            std::cerr << "No keyboard input -> GATE stays 0.\n";
            return;
        }

        std::cerr << "Keyboard input: " << cfg.devicePath << " (notes: q2w3er5t6y7u)\n";

        input_event ev{};
        std::bitset<128> pressedNotesBits = readPressedBitsFromKernel(fd);
        state.gate.store(pressedNotesBits.any(), std::memory_order_relaxed);
        state.note.store(-1, std::memory_order_relaxed);
        while (state.running.load(std::memory_order_relaxed)) {
            ssize_t n = read(fd, &ev, sizeof(ev));
            if (n == static_cast<ssize_t>(sizeof(ev))) {
                if (ev.type == EV_KEY) {
                    const int scaleIdx = keyToScaleIndex(ev.code);
                    if (scaleIdx >= 0) {
                        const int note = noteFromScaleIndex(scaleIdx);
                        int velocity = 0;
                        if (ev.value == 1) {
                            if (note >= 0 && note < 128) {
                                pressedNotesBits.set(static_cast<size_t>(note));
                            }
                            velocity = 127;
                            state.note.store(note, std::memory_order_relaxed);
                            printKeyDebug(true, note, velocity);
                        } else if (ev.value == 0) {
                            if (note >= 0 && note < 128) {
                                pressedNotesBits.reset(static_cast<size_t>(note));
                            }
                            velocity = 127;
                            state.note.store(note, std::memory_order_relaxed);
                            printKeyDebug(false, note, velocity);
                        } else {
                            // autorepeat ignore
                            continue;
                        }
                        state.gate.store(pressedNotesBits.any(), std::memory_order_relaxed);
                    }
                }
                continue;
            }

            if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
                std::cerr << "Read error from " << cfg.devicePath << ": " << strerror(errno) << "\n";
                break;
            }

            // Если какие-то key up события пропущены, синхронизируем фактическое состояние
            // зажатых клавиш с ядром и принудительно обновляем GATE/note.
            const std::bitset<128> kernelBits = readPressedBitsFromKernel(fd);
            if (kernelBits != pressedNotesBits) {
                pressedNotesBits = kernelBits;
                const bool gate = pressedNotesBits.any();
                state.gate.store(gate, std::memory_order_relaxed);
                if (!gate) {
                    state.note.store(-1, std::memory_order_relaxed);
                }
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }

        close(fd);
        state.gate.store(false, std::memory_order_relaxed);
        state.note.store(-1, std::memory_order_relaxed);
    });
}
