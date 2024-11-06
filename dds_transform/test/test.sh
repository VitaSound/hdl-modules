iverilog -o testbench testbench.v ../../dds/dds.v ../dds2tria.v ../dds2saw.v ../dds2revsaw.v ../dds2square.v ../dds2pwm.v
vvp testbench
gtkwave out.vcd