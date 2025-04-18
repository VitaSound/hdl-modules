#include "Vgenerator.h"
#include "verilated.h"
#include <portaudio.h>
#include <cstdint>

// Параметры аудио
#define SAMPLE_RATE 48000  // Частота дискретизации звука
#define FRAMES_PER_BUFFER 64  // Размер буфера

// Функция обратного вызова PortAudio
int audioCallback(const void *input, void *output,
                  unsigned long frameCount,
                  const PaStreamCallbackTimeInfo* timeInfo,
                  PaStreamCallbackFlags statusFlags,
                  void *userData) {
    Vgenerator* top = (Vgenerator*)userData;
    int16_t* out = (int16_t*)output;

    for (unsigned int i = 0; i < frameCount; i++) {
        // Эмулируем тактовый сигнал
        top->clk = 0; top->eval(); // Негативный фронт
        top->clk = 1; top->eval(); // Позитивный фронт

        // Преобразуем меандр в аудиосигнал
        out[i] = top->audio_out ? 32767 : -32768; // Меандр → PCM
    }
    return paContinue;
}

int main() {
    // Инициализация Verilator
    Verilated::commandArgs(0, (char**)nullptr);
    Vgenerator* top = new Vgenerator;

    // Инициализация PortAudio
    PaError err = Pa_Initialize();
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    PaStream* stream;
    err = Pa_OpenDefaultStream(&stream, 0, 1, paInt16, SAMPLE_RATE, FRAMES_PER_BUFFER, audioCallback, top);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    err = Pa_StartStream(stream);
    if (err != paNoError) {
        fprintf(stderr, "PortAudio error: %s\n", Pa_GetErrorText(err));
        return 1;
    }

    printf("Playing sound... Press Ctrl+C to stop.\n");
    while (true) {
        // Бесконечный цикл для воспроизведения звука
    }

    // Очистка ресурсов
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    delete top;
    return 0;
}
