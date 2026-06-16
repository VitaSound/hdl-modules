TARGET = obj_dir/Vgenerator

VERILATOR_FLAGS = --cc --exe
LDFLAGS = -lpthread

RTL_SRCS = generator.sv
CPP_SRCS = \
	main.cpp \
	engine.cpp \
	synth_core.cpp \
	net_socket.cpp

.PHONY: all clean test_hdl_net

all: $(TARGET) test_hdl_net

test_hdl_net: protocol/test_hdl_net.cpp protocol/hdl_net.h
	g++ -std=c++17 -Wall -Wextra -I. -o test_hdl_net protocol/test_hdl_net.cpp
	./test_hdl_net

$(TARGET): $(RTL_SRCS) $(CPP_SRCS)
	verilator $(VERILATOR_FLAGS) $(RTL_SRCS) $(CPP_SRCS) \
		--Mdir obj_dir --top-module generator \
		--build -o Vgenerator -LDFLAGS "$(LDFLAGS)"

clean:
	rm -rf obj_dir test_hdl_net
