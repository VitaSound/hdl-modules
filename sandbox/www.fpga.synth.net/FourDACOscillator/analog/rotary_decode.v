// rotary_decode.v: rotary encoder interface
// copied from Xilinx documentation
// 2006-07-02 E. Brombaugh

module rotary_decode(clk, rotary_a, rotary_b,
					rotary_event, rotary_left);
	input clk;
	input rotary_a;
	input rotary_b;
	output rotary_event;
	output rotary_left;
	
	// Filter / Debounce logic
	reg rotary_q1;
	reg rotary_q2;
	
	always @(posedge clk)
		case({rotary_b,rotary_a})
			2'b00:
				begin
					rotary_q1 <= 1'b0;
					rotary_q2 <= rotary_q2;
				end
			
			2'b01:
				begin
					rotary_q1 <= rotary_q1;
					rotary_q2 <= 1'b0;
				end
			
			2'b10:
				begin
					rotary_q1 <= rotary_q1;
					rotary_q2 <= 1'b1;
				end
			
			2'b11:
				begin
					rotary_q1 <= 1'b1;
					rotary_q2 <= rotary_q2;
				end
			
			default:
				begin
					rotary_q1 <= rotary_q1;
					rotary_q2 <= rotary_q2;
				end
		endcase
	
	// Decode direction & event
	reg delay_rotary_q1;
	reg rotary_event;
	reg rotary_left;
	always @(posedge clk)
	begin
		delay_rotary_q1 <= rotary_q1;
		
		if(rotary_q1 & !delay_rotary_q1)
		begin
			rotary_event <= 1'b1;
			rotary_left <= rotary_q2;
		end
		else
		begin
			rotary_event <= 1'b0;
			rotary_left <= rotary_left;
		end	
	end
endmodule

