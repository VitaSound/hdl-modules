`timescale 1us / 1ns

module tbsinetabledds();

parameter N = 7;

reg CLK;
reg RESET;

reg [7:0] NOTE; 
wire [31:0] ADDER;
wire [31:0] DDS;
reg [6:0] pulse_width;
reg [2:0] form;
wire [31:0] DDSout_sine;

reg [N-1:0] angle; 
reg [N:0] t_even;
reg [N:0] t_odd;   
reg [1:0] quadrant; 

initial NOTE = 8'd00000069;


sinetabledds STableDDS(
  .CLK(CLK),
  .RESET(RESET),
  .DDS(DDS),               
  .DDSout_sine(DDSout_sine));

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