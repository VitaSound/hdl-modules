`timescale 1us / 1ns

module tbsinetable();

reg clk;
//reg reset;

wire [N:0] sin = 0;
parameter N = 7;         //Зачем их объявлять и инициализировать
parameter N_DIVIDE = 0; //повторно, ведь это сделано в
                          //sinetable.vvvp qqq
reg [N:0] t4 = 0;   //

wire [N+1+N_DIVIDE:0] accumulator = 0;   //
reg [N-1:0] angle = 0;   //
reg [N:0] t_even = 0;   // 
reg [N:0] t_odd = 0;   //
reg [1:0] quadrant = 0;   //

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