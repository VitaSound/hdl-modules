// counter_ud.v: simple up/down counter for test purposes
// 2006-06-21 E. Brombaugh

module counter_ud(clk, reset, ena, dir, out);
	parameter dsz = 8;			// counter width
	input clk;
	input reset;
	input ena;
	input dir;
	output [dsz-1:0] out;
	
	reg [dsz-1:0] out;
	
	// synchronous binary up counter with enable
	always @(posedge clk)
		if(reset)
			out <= {dsz{1'b0}};
		else
			if(ena)
				if(dir)
					out <= out + 1;
				else
					out <= out - 1;
endmodule

