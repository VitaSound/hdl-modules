iverilog -o qqq top.v note2dds_1st_gen.v dds.v form_wave_001.v form_wave_dds31.v ttop.v
vvp qqq
gtkwave bench.vcd