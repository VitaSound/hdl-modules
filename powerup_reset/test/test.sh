iverilog -o testbench testbench.v ../powerup_reset.v
vvp testbench
gtkwave out.vcd
