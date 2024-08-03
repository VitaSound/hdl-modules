`timescale 1us / 1ns

module tbsinetabledds();

parameter N = 7;

reg CLK;
reg RESET;

wire [31:0] DDS;
wire [31:0] out_sine;

reg [N-1:0] angle; 
reg [N:0] t_even;
reg [N:0] t_odd;   
reg [1:0] quadrant; 


DDS DDS_1(
  .CLK(CLK),
  .RESET(RESET),
  .ADDER(100000),
  .DDS(DDS));

sinetabledds STableDDS(
  .CLK(CLK),
  .RESET(RESET),
  .DDS(DDS),               
  .out_sine(out_sine));

//assume basic clock is 10Mhz

initial CLK = 0;
always
  #0.05 CLK = ~CLK;

//assume basic clock is 10Mhz

//make reset signal at begin of simulation


initial
begin
  $dumpfile("out.vcd");
  $dumpvars(0,tbsinetabledds);

  #10000;

  $finish;
end

initial
begin
  RESET <= 1;
  #100;
  RESET <= 0;
end

endmodule