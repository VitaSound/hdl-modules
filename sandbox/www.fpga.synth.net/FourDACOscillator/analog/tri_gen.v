// tri_gen.v: Triangle generator
// 2006-07-02 E. Brombaugh

module tri_gen(clk, phs_in, tri_out);
	parameter psz = 12;		// phase bitwidth
	parameter osz = 12;		// output bitwidth
	
	input clk;							// clock input
	input [psz-1:0] phs_in;				// Phase input
	output signed [osz-1:0] tri_out;	// Triangle data output
	
	// break input phase up into components
	wire sign;
	wire dir;
	wire [psz-3:0] value;
	assign {sign,dir,value} = phs_in;
	
	// ones complement value when dir is active
	wire [psz-3:0] ivalue;
	assign ivalue = dir ? ~value : value;
	
	// twos complement ivalue sign of value when sign active
	wire signed [osz-1:0] tri_out;
	assign tri_out = sign ? 0 - {1'b0,ivalue} : {1'b0,ivalue}; 
endmodule
