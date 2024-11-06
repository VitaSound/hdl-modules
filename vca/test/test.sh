iverilog -o testbench testbench.v ../svca.v ../svca32.v ../svca_wide.v ../../dds/dds.v ../../dds_transform/dds2square.v ../../dds_transform/dds2tria.v
vvp testbench
gtkwave test.gtkw