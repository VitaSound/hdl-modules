# Имя исполняемого файла
TARGET = obj_dir/Vgenerator

# Verilator и PortAudio
VERILATOR_FLAGS = --cc --exe
PORTAUDIO_LIBS = -lportaudio -lasound -lpthread

# Исходные файлы
RTL_SRCS = generator.sv
CPP_SRCS = \
	main.cpp \
	synth_core.cpp \
	terminal_input.cpp \
	input_keyboard.cpp \
	input_midi.cpp \
	output_soundcard.cpp \
	output_wav.cpp

# Правила сборки
all: $(TARGET)

$(TARGET): $(RTL_SRCS) $(CPP_SRCS)
	# Генерация C++ и makefile через Verilator.
	verilator $(VERILATOR_FLAGS) $(RTL_SRCS) $(CPP_SRCS) --Mdir obj_dir --top-module generator --build -o Vgenerator -LDFLAGS "$(PORTAUDIO_LIBS)"

clean:
	rm -rf obj_dir
