module strobe_gen(clk, f, signal_out);
		
	input wire f;
	input wire clk;
	output wire signal_out;
			
	reg prev;

	initial begin
		prev <= 1'b0;
	end
		
	always @(posedge clk) begin
		prev <= f;
	end

    assign signal_out = ((f==1'b1)&&(prev==1'b0));
endmodule
