TESTER = ../../hdl-modules-tester
TARGET = obj_dir/NoiseBox

VERILATOR_FLAGS = --cc --exe -Wno-WIDTH -Wno-INITIALDLY
LDFLAGS = -lpthread
VT_CFLAGS = -I.. -I../../../hdl-modules-tester

RTL_SRCS = top.sv ../../rnd/rndx.v
CPP_SRCS = \
	synth_core.cpp \
	main.cpp \
	$(TESTER)/engine.cpp \
	$(TESTER)/net_socket.cpp \
	$(TESTER)/midi_decode.cpp

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(RTL_SRCS) $(CPP_SRCS) synth_core.h $(TESTER)/engine.h $(TESTER)/protocol/hdl_net.h
	verilator $(VERILATOR_FLAGS) $(RTL_SRCS) $(CPP_SRCS) \
		--Mdir obj_dir --top-module noise_box \
		-CFLAGS "$(VT_CFLAGS)" \
		--build -o NoiseBox -LDFLAGS "$(LDFLAGS)"

clean:
	rm -rf obj_dir
