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
<<<<<<< HEAD
wire [31:0] DDSout_sine;
=======
wire [31:0] DDSout_dds31;
>>>>>>> 4b2a03209d8b43aea4f994786b0bed32c57f67aa

reg [N-1:0] angle; 
reg [N:0] t_even;
reg [N:0] t_odd;   
reg [1:0] quadrant; 

initial NOTE = 8'd00000069;


<<<<<<< HEAD
sinetabledds STableDDS(
  .CLK(CLK),
  .RESET(RESET),
  .DDS(DDS),               
  .DDSout_sine(DDSout_sine));

//assume basic clock is 10Mhz

initial CLK = 0;
always
  #0.05 CLK = ~CLK;
=======
sinetable STable(
	.CLK(CLK),
  .RESET(RESET),
  .DDS(DDS),               
  .DDSout_dds31(DDSout_dds31), 
	.angle(angle),  
	.t_even(t_even),
	.t_odd(t_odd),   
	.quadrant(quadrant));



//assume basic clock is 10Mhz

initial clk=0;
always
  #0.05 clk = ~clk;
>>>>>>> 4b2a03209d8b43aea4f994786b0bed32c57f67aa

//make reset signal at begin of simulation


initial
begin
  $dumpfile("out.vcd");
<<<<<<< HEAD
  $dumpvars(0,tbsinetabledds);
=======
  $dumpvars(0,tbsinetable);
>>>>>>> 4b2a03209d8b43aea4f994786b0bed32c57f67aa

  #10000;

  $finish;
end
<<<<<<< HEAD

initial
begin
  RESET <= 1;
  #100;
  RESET <= 0;
end

=======
>>>>>>> 4b2a03209d8b43aea4f994786b0bed32c57f67aa
endmodule