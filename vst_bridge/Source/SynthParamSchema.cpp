#include "SynthParamSchema.h"

#include <algorithm>
#include <array>

namespace {

juce::String trimValue(juce::String s) {
    s = s.trim();
    if ((s.startsWithChar('"') && s.endsWithChar('"')) ||
        (s.startsWithChar('\'') && s.endsWithChar('\''))) {
        return s.substring(1, s.length() - 1);
    }
    return s;
}

int parseIntValue(const juce::String& text, int fallback = 0) {
    const auto trimmed = trimValue(text);
    return trimmed.isNotEmpty() ? trimmed.getIntValue() : fallback;
}

std::vector<int> parseInlineIntList(juce::String text) {
    std::vector<int> out;
    text = text.fromFirstOccurrenceOf("[", false, false)
               .upToFirstOccurrenceOf("]", false, false);
    for (auto item : juce::StringArray::fromTokens(text, ",", "")) {
        item = item.trim();
        if (item.isNotEmpty()) {
            out.push_back(item.getIntValue());
        }
    }
    return out;
}

juce::String cacheTextPath() {
    auto dir = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
                   .getChildFile("VitaSound")
                   .getChildFile("RemoteSynth");
    dir.createDirectory();
    return dir.getChildFile("param_schema_cache.yaml").getFullPathName();
}

juce::String hostCachePath() {
    auto dir = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
                   .getChildFile("VitaSound")
                   .getChildFile("RemoteSynth");
    dir.createDirectory();
    return dir.getChildFile("engine_host.txt").getFullPathName();
}

uint32_t fnv1a32(const juce::String& text) {
    uint32_t hash = 2166136261u;
    const auto utf8 = text.toRawUTF8();
    for (const auto* p = reinterpret_cast<const unsigned char*>(utf8); *p != 0; ++p) {
        hash ^= *p;
        hash *= 16777619u;
    }
    return hash;
}

SynthParamSchema parseYamlSchema(const juce::String& yaml, const juce::String& source, uint32_t hash) {
    SynthParamSchema schema;
    schema.source = source;
    schema.hash = hash != 0 ? hash : fnv1a32(yaml);

    SynthParam* current = nullptr;
    bool inChoices = false;

    for (auto rawLine : juce::StringArray::fromLines(yaml)) {
        const auto line = rawLine.trimEnd();
        const auto trimmed = line.trim();
        if (trimmed.isEmpty() || trimmed.startsWithChar('#')) {
            continue;
        }

        if (trimmed.startsWith("- id:")) {
            schema.params.push_back({});
            current = &schema.params.back();
            current->id = trimValue(trimmed.fromFirstOccurrenceOf(":", false, false));
            inChoices = false;
            continue;
        }

        if (current == nullptr) {
            if (trimmed.startsWith("id:")) {
                schema.synthId = trimValue(trimmed.fromFirstOccurrenceOf(":", false, false));
            } else if (trimmed.startsWith("title:")) {
                schema.title = trimValue(trimmed.fromFirstOccurrenceOf(":", false, false));
            } else if (trimmed.startsWith("midi_channel:")) {
                schema.midiChannel = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false), 1);
            }
            continue;
        }

        if (inChoices && trimmed.startsWith("- ")) {
            current->choices.add(trimValue(trimmed.substring(2)));
            continue;
        }

        inChoices = false;
        if (trimmed.startsWith("name:")) {
            current->name = trimValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("group:")) {
            current->group = trimValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("type:")) {
            current->type = trimValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("cc_lsb:")) {
            current->ccLsb = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("cc_msb:")) {
            current->ccMsb = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("cc:")) {
            current->cc = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("default:")) {
            current->defaultValue = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("min:")) {
            current->minValue = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false));
        } else if (trimmed.startsWith("max:")) {
            current->maxValue = parseIntValue(trimmed.fromFirstOccurrenceOf(":", false, false), 127);
        } else if (trimmed.startsWith("choices:")) {
            inChoices = true;
        } else if (trimmed.startsWith("midi_values:")) {
            current->midiValues = parseInlineIntList(trimmed.fromFirstOccurrenceOf(":", false, false));
        }
    }

    schema.params.erase(
        std::remove_if(schema.params.begin(),
                       schema.params.end(),
                       [](const SynthParam& p) { return p.id.isEmpty() || p.type.isEmpty(); }),
        schema.params.end());
    return schema;
}

juce::String fallbackYaml() {
    return R"(schema_version: 1
id: fallback
title: Fallback Synth
midi_channel: 1
params:
  - id: waveform
    name: Waveform
    group: Oscillator
    type: choice
    cc: 48
    default: 0
    choices:
      - Saw
      - Square
      - Triangle
      - Sine
      - Ramp
      - PWM
    midi_values: [0, 16, 32, 48, 64, 80]
  - id: filter_cutoff
    name: Filter Cutoff
    group: Filter
    type: cc14_log
    cc_lsb: 74
    cc_msb: 106
    default: 8192
    min: 0
    max: 16383
)";
}

bool fetchSchemaFromServer(const juce::String& host, uint16_t port, juce::String& yaml, uint32_t& hash) {
    juce::DatagramSocket socket(false);
    if (!socket.bindToPort(0)) {
        return false;
    }

    std::array<uint8_t, sizeof(hdlnet::ControlHeader)> request{};
    hdlnet::writeControlHeader(request.data(), hdlnet::PacketType::ParamSchemaRequest, 1, 0);
    if (socket.write(host, static_cast<int>(port), request.data(), static_cast<int>(request.size())) <= 0) {
        return false;
    }

    if (socket.waitUntilReady(true, 250) <= 0) {
        return false;
    }

    std::array<uint8_t, hdlnet::kMaxParamSchemaBytes + 64> response{};
    juce::String sender;
    int senderPort = 0;
    const int n = socket.read(response.data(), static_cast<int>(response.size()), false, sender, senderPort);
    if (n <= 0) {
        return false;
    }

    hdlnet::ControlHeader hdr{};
    hdlnet::PacketType type{};
    if (!hdlnet::readControlHeader(response.data(), static_cast<size_t>(n), hdr, type) ||
        type != hdlnet::PacketType::ParamSchemaData) {
        return false;
    }

    const uint8_t* data = nullptr;
    uint32_t length = 0;
    if (!hdlnet::decodeParamSchema(response.data() + sizeof(hdlnet::ControlHeader),
                                   hdr.payload_len,
                                   hash,
                                   data,
                                   length) ||
        length == 0) {
        return false;
    }
    yaml = juce::String::fromUTF8(reinterpret_cast<const char*>(data), static_cast<int>(length));
    return yaml.isNotEmpty();
}

void writeCache(const juce::String& yaml) {
    juce::File(cacheTextPath()).replaceWithText(yaml);
}

juce::String readCache() {
    const juce::File cache(cacheTextPath());
    return cache.existsAsFile() ? cache.loadFileAsString() : juce::String{};
}

float normalizedDefault(const SynthParam& param) {
    if (param.type == "choice") {
        const int n = juce::jmax(1, param.choices.size());
        return static_cast<float>(juce::jlimit(0, n - 1, param.defaultValue)) /
               static_cast<float>(juce::jmax(1, n - 1));
    }
    const int range = juce::jmax(1, param.maxValue - param.minValue);
    return static_cast<float>(juce::jlimit(param.minValue, param.maxValue, param.defaultValue) -
                              param.minValue) /
           static_cast<float>(range);
}

} // namespace

const SynthParam* findSynthParam(const SynthParamSchema& schema, const juce::String& paramId) {
    for (const auto& param : schema.params) {
        if (param.id == paramId) {
            return &param;
        }
    }
    return nullptr;
}

SynthParamSchema loadRuntimeSynthParamSchema(const juce::String& host, uint16_t port) {
    juce::String yaml;
    uint32_t hash = 0;
    if (fetchSchemaFromServer(host, port, yaml, hash)) {
        writeCache(yaml);
        return parseYamlSchema(yaml, "server", hash);
    }

    yaml = readCache();
    if (yaml.isNotEmpty()) {
        return parseYamlSchema(yaml, "cache", fnv1a32(yaml));
    }

    yaml = fallbackYaml();
    return parseYamlSchema(yaml, "fallback", fnv1a32(yaml));
}

juce::String loadCachedSynthParamHost() {
    const juce::File file(hostCachePath());
    const auto host = file.existsAsFile() ? file.loadFileAsString().trim() : juce::String{};
    return host.isNotEmpty() ? host : "127.0.0.1";
}

void saveCachedSynthParamHost(const juce::String& host) {
    const auto trimmed = host.trim();
    if (trimmed.isNotEmpty()) {
        juce::File(hostCachePath()).replaceWithText(trimmed);
    }
}

juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout(const SynthParamSchema& schema) {
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;
    for (const auto& param : schema.params) {
        if (param.type == "choice") {
            params.push_back(std::make_unique<juce::AudioParameterChoice>(
                juce::ParameterID{param.id, 1},
                param.name.isNotEmpty() ? param.name : param.id,
                param.choices,
                juce::roundToInt(normalizedDefault(param) * juce::jmax(0, param.choices.size() - 1))));
        } else {
            params.push_back(std::make_unique<juce::AudioParameterFloat>(
                juce::ParameterID{param.id, 1},
                param.name.isNotEmpty() ? param.name : param.id,
                juce::NormalisableRange<float>(0.0f, 1.0f),
                normalizedDefault(param)));
        }
    }
    return {params.begin(), params.end()};
}

void sendParamAsMidi(const SynthParamSchema& schema,
                     juce::AudioProcessorValueTreeState& apvts,
                     const juce::String& paramId,
                     float normalizedValue,
                     const std::function<void(const std::vector<uint8_t>&)>& sendBytes) {
    const auto* param = findSynthParam(schema, paramId);
    if (param == nullptr) {
        return;
    }

    auto* parameter = apvts.getParameter(paramId);
    const float raw = parameter != nullptr ? parameter->getValue() : normalizedValue;
    const float clamped = juce::jlimit(0.0f, 1.0f, raw);
    const uint8_t status = static_cast<uint8_t>(0xB0 + juce::jlimit(0, 15, schema.midiChannel - 1));

    if (param->type == "cc14_log") {
        if (param->ccMsb < 0 || param->ccLsb < 0) {
            return;
        }
        const int value14 = juce::roundToInt(clamped * 16383.0f);
        sendBytes({status,
                   static_cast<uint8_t>(param->ccLsb),
                   static_cast<uint8_t>((value14 >> 7) & 0x7F)});
        sendBytes({status,
                   static_cast<uint8_t>(param->ccMsb),
                   static_cast<uint8_t>(value14 & 0x7F)});
        return;
    }

    if (param->cc < 0) {
        return;
    }

    if (param->type == "choice") {
        const int n = juce::jmax(1, param->choices.size());
        const int idx = juce::jlimit(0, n - 1, juce::roundToInt(clamped * static_cast<float>(juce::jmax(0, n - 1))));
        const int ccValue = idx < static_cast<int>(param->midiValues.size())
                                ? param->midiValues[static_cast<size_t>(idx)]
                                : juce::roundToInt(clamped * 127.0f);
        sendBytes({status, static_cast<uint8_t>(param->cc), static_cast<uint8_t>(juce::jlimit(0, 127, ccValue))});
        return;
    }

    const int ccValue = juce::roundToInt(clamped * 127.0f);
    sendBytes({status, static_cast<uint8_t>(param->cc), static_cast<uint8_t>(ccValue)});
}
