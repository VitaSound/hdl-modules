iverilog -o testbench testbench.v ../adsr.v ../../common/frqdivmod.v
vvp testbench
# gtkwave out.vcd
gtkwave test.gtkw