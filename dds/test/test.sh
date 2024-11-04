iverilog -o testbench testbench.v ../dds.v
vvp testbench
gtkwave out.vcd