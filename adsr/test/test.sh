iverilog -o testbench testbench.v ../adsr.v ../../common/frqdivmod.v ../../common/powerup_reset.v ../../common/strobe_gen.v
vvp testbench
# gtkwave out.vcd
gtkwave test.gtkw