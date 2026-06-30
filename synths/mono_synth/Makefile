TESTER = ../../hdl-modules-tester
TARGET = obj_dir/MonoSynth

VERILATOR_FLAGS = --cc --exe -Wno-WIDTH -Wno-INITIALDLY -Wno-CASEINCOMPLETE -Wno-IMPLICIT
LDFLAGS = -lpthread
VT_CFLAGS = -I.. -I../../../hdl-modules-tester

RTL_SRCS = \
	top.sv \
	../../io/midi_in.v \
	../../mono_voice/mono_voice.v \
	../../dds/note2dds.v \
	../../dds/note_pitch2dds.v \
	../../dds/dds.v \
	../../dds_transform/dds2saw.v \
	../../dds_transform/dds2revsaw.v \
	../../dds_transform/dds2tria.v \
	../../dds_transform/dds2square.v \
	../../dds_transform/dds2pwm.v \
	../../dds_transform/dds2sin.v \
	../../adsr/adsr.v \
	../../common/frqdivmod.v \
	../../common/strobe_gen.v \
	../../common/param_reg.v \
	../../common/reg7.v \
	../../common/reg14.v \
	../../common/note_mono.v \
	../../common/bitscan.v \
	../../common/prio_encoder.v \
	../../common/lin2exp_t.v \
	../../svf/svf.v \
	../../svf/svf_fcut_mix.v \
	../../svf/note_fcut_lut.v \
	../../lfo/lfo.v \
	../../lfo/lfo_rate_lut.v \
	svf_cutoff14_to_f.v \
	svf_cc_to_q.v \
	../../vca/svca16.v \
	../../vca/svca.v

CPP_SRCS = \
	synth_core.cpp \
	main.cpp \
	$(TESTER)/engine.cpp \
	$(TESTER)/net_socket.cpp \
	$(TESTER)/midi_decode.cpp

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(RTL_SRCS) $(CPP_SRCS) synth_core.h $(TESTER)/engine.h $(TESTER)/protocol/hdl_net.h $(TESTER)/midi_events.h
	verilator $(VERILATOR_FLAGS) $(RTL_SRCS) $(CPP_SRCS) \
		--Mdir obj_dir --top-module mono_synth \
		-CFLAGS "$(VT_CFLAGS)" \
		--build -o MonoSynth -LDFLAGS "$(LDFLAGS)"

clean:
	rm -rf obj_dir
