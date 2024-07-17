`timescale 1us / 1ns

module tbsinetable();

parameter N = 7;

reg clk;
wire [N:0] sin;
//reg reset;



sinetable STable(
  .clk(clk), 
  .sin(sin));

//assume basic clock is 10Mhz

initial clk=0;
always
  #0.05 clk = ~clk;

//make reset signal at begin of simulation


initial
begin
  $dumpfile("out.vcd");
  $dumpvars(0,tbsinetable);

  #10000;

  $finish;
end
endmodule