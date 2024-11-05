// sine_gen.v: lookup sine and cosine values from phase
// 2006-07-02 E. Brombaugh

module sine_gen(clk, phs, sin, cos);
	parameter psz = 12;						// Bits in phase word
	parameter osz = 18;						// Bits in output words
	
	input clk;								// Main system clock (122 MHz)
	output signed [osz-1:0] sin, cos;		// output, 4x TDM

	input signed [psz-1:0] phs;				// Output of phase acc
	wire sai, cai, sdi, cdi;				// Address/Data inversion bits
	wire [psz-3:0] sadd, cadd;				// sin & cos addresses
	reg sdid0, cdid0, sdid1, cdid1;			// delayed data invert bits
	wire signed [osz-1:0] rsin, rcos;		// raw values (all positive)
	reg signed [osz-1:0] psin, pcos;		// unregistered outputs
	reg signed [osz-1:0] sin, cos;			// outputs
		
	// Split phase up into contols bits
	assign sai = phs[psz-2];				// invert sine address in odd quads
	assign cai = ~phs[psz-2];				// invert cos address in even quads
	assign sdi = phs[psz-1];				// invert sine data in back half
	assign cdi = phs[psz-1]^phs[psz-2];		// invert cos data in center half
	
	// Invert phs lsbs to create sin & cos addresses
	assign sadd = {psz-2{sai}} ^ phs[psz-3:0];
	assign cadd = {psz-2{cai}} ^ phs[psz-3:0];

	// delay data invert bits
	always @(posedge clk)
	begin
		sdid0 <= sdi;
		cdid0 <= cdi;
		sdid1 <= sdid0;
		cdid1 <= cdid0;
	end
	
	// Lookup raw sin & cos data (1 cycle delay)
	sc_lut u0(.clk(clk), .a0(sadd), .a1(cadd), .d0(rsin), .d1(rcos));
	
	// async invert data outputs
	always @(rsin or rcos or sdid1 or cdid1)
	begin
		psin = ({osz{sdid1}} ^ rsin) + {{osz{1'b0}},sdid1};
		pcos = ({osz{cdid1}} ^ rcos) + {{osz{1'b0}},cdid1};
	end
	
	// Sync output registers
	always @(posedge clk)
	begin
		sin <= psin;
		cos <= pcos;
	end
endmodule

	
