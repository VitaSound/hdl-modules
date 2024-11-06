iverilog -o testbench testbench.v ../rnd1.v ../rnd8.v ../rndx.v
vvp testbench
# gtkwave out.vcd
gtkwave test.gtkw