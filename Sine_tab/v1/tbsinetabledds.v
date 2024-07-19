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
wire [31:0] DDSout_dds31;

reg [N-1:0] angle; 
reg [N:0] t_even;
reg [N:0] t_odd;   
reg [1:0] quadrant; 

initial NOTE = 8'd00000069;


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

//make reset signal at begin of simulation


initial
begin
  $dumpfile("out.vcd");
  $dumpvars(0,tbsinetable);

  #10000;

  $finish;
end
endmodule