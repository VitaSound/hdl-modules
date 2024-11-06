iverilog -o testbench testbench.v ../frqdivmod.v ../strobe_gen.v
vvp testbench
# gtkwave out.vcd
gtkwave test.gtkw
