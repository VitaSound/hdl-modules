`timescale 1us / 1ns

module tbsinewave();

reg clk;
reg reset;

wire [31:0]cnt;
wire cnt_edge;
wire [15:0]sin_val;


sinewave sin1(clk, reset, cnt, cnt_edge, sin_val);

//assume basic clock is 10Mhz

initial clk=0;
always
  #0.05 clk = ~clk;

//make reset signal at begin of simulation

initial
begin
  reset = 1;
  #0.1;
  reset = 0;
end

initial
begin
  $dumpfile("out.vcd");
  $dumpvars(0,tbsinewave);

  #10000;

  $finish;
end
endmodule