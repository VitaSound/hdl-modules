testbench.v файл-исходник, в котором всё хорошо считатеся синус волна 

iverilog -o qqq testbench.v
vvp qqq
gtkwave out.vcd