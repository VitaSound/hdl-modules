# Legacy local realtime synth (keyboard/MIDI → soundcard/wav).
# UDP engine for VST: ../hdl-modules-tester/

TARGET = obj_dir/Vgenerator
TARGET_FULL = obj_dir/VgeneratorFull

VERILATOR_FLAGS = --cc --exe
PORTAUDIO_LIBS = -lportaudio -lasound -lpthread
FULL_CFLAGS = -DSYNTH_CORE_FULLRANGE

RTL_SRCS = generator.sv
RTL_FULL_SRCS = generator_fullrange.sv

COMMON_CPP = \
	terminal_input.cpp \
	input_keyboard.cpp \
	input_midi.cpp \
	output_soundcard.cpp \
	output_wav.cpp

CPP_SRCS = \
	main.cpp \
	synth_core.cpp \
	$(COMMON_CPP)

CPP_FULL_SRCS = \
	main_fullrange.cpp \
	synth_core_fullrange.cpp \
	$(COMMON_CPP)

.PHONY: all full clean

all: $(TARGET)

full: $(TARGET_FULL)

$(TARGET): $(RTL_SRCS) $(CPP_SRCS)
	verilator $(VERILATOR_FLAGS) $(RTL_SRCS) $(CPP_SRCS) \
		--Mdir obj_dir --top-module generator \
		--build -o Vgenerator -LDFLAGS "$(PORTAUDIO_LIBS)"

$(TARGET_FULL): $(RTL_FULL_SRCS) $(CPP_FULL_SRCS)
	verilator $(VERILATOR_FLAGS) $(RTL_FULL_SRCS) $(CPP_FULL_SRCS) \
		--Mdir obj_dir --top-module generator_fullrange \
		-CFLAGS "$(FULL_CFLAGS)" \
		--build -o VgeneratorFull -LDFLAGS "$(PORTAUDIO_LIBS)"

clean:
	rm -rf obj_dir
