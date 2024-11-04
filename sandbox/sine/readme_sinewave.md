Файлы sinewave.v и tbsinewave.v получены из файла testbench.v

iverilog -o qqq sinewave.v tbsinewave.v
vvp qqq
gtkwave out.vcd