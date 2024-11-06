// not signed, symmetric max/2
module svca32(in, cv, signal_out); //
parameter WIDTH = 32; //

input wire [31:0] in, cv;
output wire [31:0] signal_out;


wire signed [16:0] s_in = in[31:16] - 16'd32768; 
wire signed [16:0] s_cv = cv[31:16];

wire signed [32:0] result_s = s_in * s_cv;
// wire [32:0]   result_sss = result_s + 16'd32768;
// assign signal_out = result_sss[15:0];

// wire signed [32:0]   result_ss = result_s >>> 16;
wire [32:0]   result_sss = result_s  + {1'b1, {31'b0}};
assign signal_out = result_sss[31:0];

endmodule
