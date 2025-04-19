#include "Vgenerator.h"
#include "verilated.h"
#include <portaudio.h>
#include <cstdint>
#include <fstream>

#include <iostream>
#include <thread>
#include <linux/input.h>
#include <fcntl.h>
#include <unistd.h>
#include <atomic>
#include <iostream>

// Глобальная переменная для управления enable
std::atomic<bool> enable(false);

// Функция для отслеживания нажатий клавиш
void keyPressHandler() {
    const char* device = "/dev/input/event2"; // Устройство клавиатуры
    int fd = open(device, O_RDONLY);
    if (fd == -1) {
        perror("Failed to open input device");
        return;
    }

    struct input_event ev;
    while (true) {
        read(fd, &ev, sizeof(struct input_event));
        if (ev.type == EV_KEY && ev.code == KEY_1) { // Клавиша '1'
            if (ev.value == 1) { // Нажата
                enable = true;
            } else if (ev.value == 0) { // Отпущена
                enable = false;
            }
        }
    }

    close(fd);
}

// Параметры аудио
#define SAMPLE_RATE 48000  // Частота дискретизации звука
#define FRAMES_PER_BUFFER 64  // Размер буфера

// Глобальные переменные для записи в WAV
std::ofstream wavFile;
bool isWavRecording = false;
int numSamplesWritten = 0;

// Запись заголовка WAV
void writeWavHeader(std::ofstream& file, int sampleRate, int numSamples) {
    file.write("RIFF", 4);
    uint32_t fileSize = 36 + numSamples * 2;
    file.write((char*)&fileSize, 4);
    file.write("WAVEfmt ", 8);
    uint32_t subchunk1Size = 16;
    file.write((char*)&subchunk1Size, 4);
    uint16_t audioFormat = 1; // PCM
    file.write((char*)&audioFormat, 2);
    uint16_t numChannels = 1; // Моно
    file.write((char*)&numChannels, 2);
    file.write((char*)&sampleRate, 4);
    uint32_t byteRate = sampleRate * 2; // 16-bit PCM
    file.write((char*)&byteRate, 4);
    uint16_t blockAlign = 2;
    file.write((char*)&blockAlign, 2);
    uint16_t bitsPerSample = 16;
    file.write((char*)&bitsPerSample, 2);
    file.write("data", 4);
    uint32_t dataSize = numSamples * 2;
    file.write((char*)&dataSize, 4);
}

// Запись семпла в WAV
void writeSample(int16_t sample) {
    if (isWavRecording && wavFile.is_open()) {
        // printf("Writing sample: %d\n", sample); // Отладочное сообщение
        wavFile.write((char*)&sample, 2);
        numSamplesWritten++;
    }
}

// Функция обратного вызова PortAudio
int audioCallback(const void* input, void* output,
                  unsigned long frameCount,
                  const PaStreamCallbackTimeInfo* timeInfo,
                  PaStreamCallbackFlags statusFlags,
                  void* userData) {
    Vgenerator* top = (Vgenerator*)userData;
    int16_t* out = (int16_t*)output;

    for (unsigned int i = 0; i < frameCount; i++) {
        // Эмулируем работу Verilog-модуля на частоте 1 МГц
        for (int j = 0; j < 21; j++) { // 21 такт на семпл
            top->clk = 0; top->eval(); // Негативный фронт
            top->clk = 1; top->eval(); // Позитивный фронт
        }

        // Устанавливаем значение enable
        top->enable = enable.load();

        // Преобразуем меандр в аудиосигнал
        int16_t sample = top->audio_out ? 32767 : -32768; // Меандр → PCM
        out[i] = sample;

        // Записываем семпл в WAV (если включено)
        writeSample(sample);
    }
    return paContinue;
}

int main() {
    // Инициализация Verilator
    const char* dummy_argv[] = { "program_name" };
    Verilated::commandArgs(1, (char**)dummy_argv);

    Vgenerator* top = new Vgenerator;

    // Запуск обработчика клавиш в отдельном потоке
    std::thread keyThread(keyPressHandler);

    // Инициализация PortAudio
    PaError err = Pa_Initialize();
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    // Поиск ALSA среди доступных хост-API
    int alsaHostApiIndex = -1;
    int numHostApis = Pa_GetHostApiCount();
    for (int i = 0; i < numHostApis; i++) {
        const PaHostApiInfo* hostApiInfo = Pa_GetHostApiInfo(i);
        if (hostApiInfo && hostApiInfo->type == paALSA) {
            alsaHostApiIndex = i;
            break;
        }
    }

    if (alsaHostApiIndex == -1) {
        fprintf(stderr, "Error: ALSA host API not found.\n");
        return 1;
    }

    // Вывод списка доступных устройств ALSA
    printf("Available ALSA devices:\n");
    int numDevices = Pa_GetDeviceCount();
    for (int i = 0; i < numDevices; i++) {
        const PaDeviceInfo* deviceInfo = Pa_GetDeviceInfo(i);
        if (deviceInfo && Pa_GetHostApiInfo(deviceInfo->hostApi)->type == paALSA) {
            printf("Device %d: %s\n", i, deviceInfo->name);
        }
    }

    // Выбор устройства (например, Card 1, Device 0)
    int outputDevice = -1;
    for (int i = 0; i < numDevices; i++) {
        const PaDeviceInfo* deviceInfo = Pa_GetDeviceInfo(i);
        if (deviceInfo && Pa_GetHostApiInfo(deviceInfo->hostApi)->type == paALSA &&
            strstr(deviceInfo->name, "ALC294 Analog") != nullptr) {
            outputDevice = i;
            break;
        }
    }

    if (outputDevice == -1) {
        fprintf(stderr, "Error: Could not find ALC294 Analog device.\n");
        return 1;
    }

    // Настройка параметров вывода
    PaStreamParameters outputParameters;
    outputParameters.device = outputDevice;
    outputParameters.channelCount = 1;                     // Моно
    outputParameters.sampleFormat = paInt16;               // 16-bit PCM
    outputParameters.suggestedLatency = Pa_GetDeviceInfo(outputParameters.device)->defaultLowOutputLatency;
    outputParameters.hostApiSpecificStreamInfo = nullptr;

    // Открываем поток
    PaStream* stream;
    err = Pa_OpenStream(&stream,
                        nullptr, // Нет входного потока
                        &outputParameters,
                        SAMPLE_RATE,
                        FRAMES_PER_BUFFER,
                        paClipOff,
                        audioCallback,
                        top);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    // Запись в WAV (опционально)
    isWavRecording = true;
    wavFile.open("output.wav", std::ios::binary);
    if (!wavFile.is_open()) {
        fprintf(stderr, "Error: Could not open output.wav for writing.\n");
        return 1;
    }
    printf("WAV file opened successfully.\n");

    // Запись начального заголовка WAV
    writeWavHeader(wavFile, SAMPLE_RATE, 0); // Начальный заголовок (обновится позже)

    // Запуск потока
    err = Pa_StartStream(stream);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    printf("Playing sound... Press Ctrl+C to stop.\n");

    // Основной цикл программы
    while (true) {
        // Бесконечный цикл для воспроизведения звука
    }

    // Остановка потока
    Pa_StopStream(stream);
    Pa_CloseStream(stream);

    // Обновление заголовка WAV перед закрытием файла
    if (wavFile.is_open()) {
        wavFile.seekp(0, std::ios::beg); // Вернуться в начало файла
        writeWavHeader(wavFile, SAMPLE_RATE, numSamplesWritten); // Обновить заголовок
        wavFile.close();
        printf("WAV file closed and header updated.\n");
    }

    // Очистка ресурсов
    Pa_Terminate();

    // Ожидание завершения потока
    keyThread.join();

    delete top;
    return 0;
}
