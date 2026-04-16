#pragma once

#include <string>
#include <thread>
#include <vector>

#include "shared_state.h"

struct MidiPortInfo {
    int client = -1;
    int port = -1;
    std::string clientName;
    std::string portName;
};

std::vector<MidiPortInfo> listMidiInputPorts();
bool parseMidiPort(const std::string& s, int& client, int& port);
std::thread startMidiInput(int srcClient, int srcPort, SharedState& state);
