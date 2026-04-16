#include "input_midi.h"

#include <alsa/asoundlib.h>
#include <array>
#include <chrono>
#include <iostream>

namespace {
void printMidiDebug(const char* eventType, bool gate, int note, int velocity) {
    std::cerr << "[midi] " << eventType
              << " | NOTE " << note
              << " | VELOCITY " << velocity
              << " | GATE " << (gate ? "ON" : "OFF")
              << "\n";
    std::cerr.flush();
}

bool anyPressed(const std::array<bool, 128>& pressed) {
    for (bool v : pressed) {
        if (v) {
            return true;
        }
    }
    return false;
}
} // namespace

std::vector<MidiPortInfo> listMidiInputPorts() {
    std::vector<MidiPortInfo> ports;
    snd_seq_t* seq = nullptr;
    if (snd_seq_open(&seq, "default", SND_SEQ_OPEN_DUPLEX, 0) < 0) {
        return ports;
    }

    snd_seq_client_info_t* cinfo = nullptr;
    snd_seq_port_info_t* pinfo = nullptr;
    snd_seq_client_info_alloca(&cinfo);
    snd_seq_port_info_alloca(&pinfo);
    snd_seq_client_info_set_client(cinfo, -1);

    while (snd_seq_query_next_client(seq, cinfo) >= 0) {
        const int client = snd_seq_client_info_get_client(cinfo);
        snd_seq_port_info_set_client(pinfo, client);
        snd_seq_port_info_set_port(pinfo, -1);
        while (snd_seq_query_next_port(seq, pinfo) >= 0) {
            const unsigned int caps = snd_seq_port_info_get_capability(pinfo);
            if ((caps & SND_SEQ_PORT_CAP_READ) == 0 || (caps & SND_SEQ_PORT_CAP_SUBS_READ) == 0) {
                continue;
            }
            MidiPortInfo port;
            port.client = client;
            port.port = snd_seq_port_info_get_port(pinfo);
            port.clientName = snd_seq_client_info_get_name(cinfo);
            port.portName = snd_seq_port_info_get_name(pinfo);
            ports.push_back(port);
        }
    }

    snd_seq_close(seq);
    return ports;
}

bool parseMidiPort(const std::string& s, int& client, int& port) {
    const size_t pos = s.find(':');
    if (pos == std::string::npos) {
        return false;
    }
    try {
        client = std::stoi(s.substr(0, pos));
        port = std::stoi(s.substr(pos + 1));
    } catch (...) {
        return false;
    }
    return client >= 0 && port >= 0;
}

std::thread startMidiInput(int srcClient, int srcPort, SharedState& state) {
    return std::thread([srcClient, srcPort, &state]() {
        snd_seq_t* seq = nullptr;
        if (snd_seq_open(&seq, "default", SND_SEQ_OPEN_DUPLEX, 0) < 0) {
            std::cerr << "Cannot open ALSA sequencer for MIDI input.\n";
            return;
        }

        snd_seq_set_client_name(seq, "verilator_tests");
        const int inPort = snd_seq_create_simple_port(
            seq,
            "midi_in",
            SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_SUBS_WRITE,
            SND_SEQ_PORT_TYPE_APPLICATION
        );
        if (inPort < 0) {
            std::cerr << "Cannot create ALSA sequencer input port.\n";
            snd_seq_close(seq);
            return;
        }

        if (snd_seq_connect_from(seq, inPort, srcClient, srcPort) < 0) {
            std::cerr << "Cannot connect MIDI source " << srcClient << ":" << srcPort << ".\n";
            snd_seq_close(seq);
            return;
        }

        snd_seq_nonblock(seq, 1);
        std::cerr << "MIDI connected: " << srcClient << ":" << srcPort << "\n";

        std::array<bool, 128> pressed{};
        while (state.running.load(std::memory_order_relaxed)) {
            snd_seq_event_t* ev = nullptr;
            const int rc = snd_seq_event_input(seq, &ev);
            if (rc == -EAGAIN) {
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
                continue;
            }
            if (rc < 0 || ev == nullptr) {
                std::cerr << "MIDI input error.\n";
                break;
            }

            if (ev->type == SND_SEQ_EVENT_NOTEON) {
                const int note = ev->data.note.note;
                const int velocity = ev->data.note.velocity;
                if (note >= 0 && note < 128) {
                    if (velocity > 0) {
                        pressed[note] = true;
                        state.note.store(note, std::memory_order_relaxed); // только NOTE ON обновляет note
                    } else {
                        // NOTE ON с velocity=0 трактуем как NOTE OFF: только сброс маски
                        pressed[note] = false;
                    }
                    const bool any = anyPressed(pressed);
                    state.gate.store(any, std::memory_order_relaxed);
                    printMidiDebug(velocity > 0 ? "NOTE ON" : "NOTE OFF", any, note, velocity);
                }
            } else if (ev->type == SND_SEQ_EVENT_NOTEOFF) {
                const int note = ev->data.note.note;
                const int velocity = ev->data.note.velocity;
                if (note >= 0 && note < 128) {
                    pressed[note] = false;
                    const bool any = anyPressed(pressed);
                    state.gate.store(any, std::memory_order_relaxed);
                    printMidiDebug("NOTE OFF", any, note, velocity);
                }
            }
        }

        state.gate.store(false, std::memory_order_relaxed);
        state.note.store(-1, std::memory_order_relaxed);
        snd_seq_close(seq);
    });
}
