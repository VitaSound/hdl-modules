module frqdivmod(clk, signal_out);
parameter DIV=2;
// Single posedge counter: stable in Icarus for odd DIV (legacy dual-edge negedge path caused X).
parameter WITH = ($clog2(DIV+1)>0) ? $clog2(DIV+1) : 1;

input wire clk;
output wire signal_out;

reg [(WITH-1):0] pos_cnt;

wire [(WITH-1):0] div_value = DIV[(WITH-1):0];
wire [(WITH-1):0] next_pos = (pos_cnt + 1'b1) % div_value;

initial
	pos_cnt <= {(WITH){1'b0}};

assign signal_out = (DIV == 1) ? clk : (pos_cnt >= (DIV / 2));

always @(posedge clk)
	pos_cnt <= next_pos;

endmodule
