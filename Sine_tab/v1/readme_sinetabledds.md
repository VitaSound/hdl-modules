iverilog -o qqq dds.v sinetabledds.v tbsinetabledds.v
vvp qqq
gtkwave out.vcd