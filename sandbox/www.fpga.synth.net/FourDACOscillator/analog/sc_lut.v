// sc_lut.v: Sine/Cosine Lookup Table
// 2006-07-02 E. Brombaugh

module	sc_lut(clk, a0, a1, d0, d1);
	parameter asz = 10;				// bits in input address words
	parameter dsz = 18;				// bits in output data word
	
	input clk;						// System clock (122 MHz)
	input [asz-1:0] a0, a1;			// input address
	output signed [dsz-1:0] d0, d1;	// output data
	
	// Xilinx Block RAM model of LUT
	wire [15:0] DOA, DOB;
	wire [1:0] DOPA, DOPB;
	reg [9:0] ADDRA, ADDRB;
	
	// delay addresses
	always @(posedge clk)
	begin
		ADDRA <= a0;
		ADDRB <= a1;
	end
	
	RAMB16_S18_S18 #(	
// The following file specifies the initial contents of the RAM
`include "sc_lut_init.v"
		)
	RAMB16_inst (
		.DOA (DOA),
		.DOB (DOB),
		.DOPA (DOPA),
		.DOPB (DOPB),
		.ADDRA (ADDRA),
		.ADDRB (ADDRB),
		.CLKA (clk),
		.CLKB (clk),
		.DIA (16'hffff),
		.DIB (16'hffff),
		.DIPA (2'b11),
		.DIPB (2'b11),
		.ENA (1'b1),
		.ENB (1'b1),
		.SSRA (1'b0),
		.SSRB (1'b0),
		.WEA (1'b0),
		.WEB (1'b0));
	
	// Combine the outputs correctly
	assign d0 = {DOPA[1:0],DOA[15:0]};
	assign d1 = {DOPB[1:0],DOB[15:0]};
endmodule
