`timescale 1us / 1ns

module tbsinewave();

reg clk;
//reg reset;

wire [N:0] sin;


wire [N+1+N_DIVIDE:0] accumulator;   
reg [N-1:0] angle;
reg [N:0] t_even, t_odd;
reg [1:0] quadrant;


sinetable(
  .clk(clk), 
  .sin(sin));

//sinewave sin1(clk, reset, cnt, cnt_edge, sin_val);

//assume basic clock is 10Mhz

initial clk=0;
always
  #0.05 clk = ~clk;

//make reset signal at begin of simulation


initial
begin
  $dumpfile("out.vcd");
  $dumpvars(0,tbsinewave);

  #10000;

  $finish;
end
endmodule