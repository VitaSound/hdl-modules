iverilog -o qqq note2dds_1st_gen.v dds.v sinetabledds.v tbsinetabledds.v
vvp qqq
gtkwave out.vcd