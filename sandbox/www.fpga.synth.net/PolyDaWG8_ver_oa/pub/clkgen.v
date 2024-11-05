// clkgen.v - master clock generator for I2S test
// Base code by: E. Brombaugh - 08-26-2008
//  Modified by: S. Gravenhorst
// @ 36.8640 MHz for 48.00 kHz sample rate (divider = 768)
// @ 50.0000 MHz for 65.1041667 Khz SR (divider = 768)
// @ 38.4000 MHz for 200 KHz SR (divider = 192)
// expanded cnt to 10 bits to accomodate divider 768

module clkgen(clk, reset, rate);
	input clk;		// system clock
	input reset;	// POR
	output rate;	// Sample rate clock output
	
  parameter DIVIDER = 192;       // This is a default, DIVIDER should be set in the instantiating module, NOT HERE.
  parameter N = DIVIDER - 1;

	// rate counter
	reg rate;
	reg [9:0] cnt;
	always @ ( posedge clk )
		if ( reset | rate ) cnt <= N;
		else                cnt <= cnt - 1;
	
	// detect end condition
	always @(posedge clk) rate <= (cnt == 10'd1);
endmodule
