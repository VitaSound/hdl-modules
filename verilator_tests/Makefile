# Legacy local realtime synth (keyboard/MIDI → soundcard/wav).
# UDP engine for VST: ../hdl-modules-tester/

TARGET = obj_dir/Vgenerator

VERILATOR_FLAGS = --cc --exe
PORTAUDIO_LIBS = -lportaudio -lasound -lpthread

RTL_SRCS = generator.sv
CPP_SRCS = \
	main.cpp \
	synth_core.cpp \
	terminal_input.cpp \
	input_keyboard.cpp \
	input_midi.cpp \
	output_soundcard.cpp \
	output_wav.cpp

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(RTL_SRCS) $(CPP_SRCS)
	verilator $(VERILATOR_FLAGS) $(RTL_SRCS) $(CPP_SRCS) \
		--Mdir obj_dir --top-module generator \
		--build -o Vgenerator -LDFLAGS "$(PORTAUDIO_LIBS)"

clean:
	rm -rf obj_dir
