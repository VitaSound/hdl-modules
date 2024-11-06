iverilog -o testbench testbench.v ../frqdivmod.v
vvp testbench
# gtkwave out.vcd
gtkwave test.gtkw
