module dds #(parameter WIDTH = 32)(clk, reset, adder, signal_out);
	input wire clk, reset;
	input [(WIDTH - 1):0] adder;

	output reg [(WIDTH - 1):0] signal_out;

	initial 
	begin
		signal_out <= 0;
	end

	always @(posedge clk) begin
		if (reset)
			signal_out <= 0;
		else
			signal_out <= signal_out + adder;
	end

endmodule
