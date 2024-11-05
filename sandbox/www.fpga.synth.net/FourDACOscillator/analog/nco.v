// nco.v: numerically controlled oscillator
// 2006-06-21 E. Brombaugh

module nco(clk, reset, ena, frq, phs);
	parameter dsz = 24;			// phase accumulator width
	input clk;
	input reset;
	input ena;
	input [dsz-1:0] frq;
	output [dsz-1:0] phs;
	
	reg [dsz-1:0] phs;
	
	// synchronous binary up counter with enable
	always @(posedge clk)
		if(reset)
			phs <= {dsz{1'b0}};
		else
			if(ena)
				phs <= phs + frq;

endmodule

