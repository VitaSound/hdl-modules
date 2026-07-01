TESTER = ../../hdl-modules-tester
TARGET = obj_dir/MiniFX

VERILATOR_FLAGS = --cc --exe -Wno-WIDTH -Wno-INITIALDLY -Wno-CASEINCOMPLETE -Wno-IMPLICIT
LDFLAGS = -lpthread
VT_CFLAGS = -I.. -I../../../hdl-modules-tester

RTL_SRCS = \
	top.sv \
	../../io/midi_in.v \
	../../common/reg7.v \
	../../common/param_reg.v \
	../../svf/svf.v \
	svf_cutoff14_to_f.v \
	svf_cc_to_q.v

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
		--Mdir obj_dir --top-module mini_fx \
		-CFLAGS "$(VT_CFLAGS)" \
		--build -o MiniFX -LDFLAGS "$(LDFLAGS)"

clean:
	rm -rf obj_dir
