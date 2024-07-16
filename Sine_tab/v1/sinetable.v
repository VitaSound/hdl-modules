module sinetable(clk, sin);
	parameter N_DIVIDE = 0; // дополнительные биты в accumulator для понижения частоты t 
	parameter N = 7; // размерность функции четверть-периода синуса

	input clk;
	output reg [N:0] sin;

	reg [N+1+N_DIVIDE:0] accumulator; // циклический счётчик изменяемый каждый такт
	wire [N-1:0] angle;         // значение t внутри квадранта
	wire [N:0] t_even, t_odd; // значения t4 для чётных и нечётных квадрантов
	wire [1:0] quadrant;   // номер квадранта

	assign {quadrant, angle} = accumulator[N+1+N_DIVIDE:N_DIVIDE];
	assign t_even = {1'b0, angle}; 
	assign t_odd = {1'b1, {N{1'b0}}} - {1'b0, angle};

    //input wire [N:0] t4 = 0; //

	function [N-1:0] sin4;
		input [N:0] t4;  // t4 
		begin
			case (t4)
				//8'd00: sin4 = 1'b0;   // добавила строку
			    //8'd01: sin4 = 1'b1;   // добавила строку
					
				 8'd00: sin4 = 0.0000;   //sin(0.0000) = 0.0000
                 8'd01: sin4 = 0.1710;    //sin(0.1718) = 0.1710
                 8'd02: sin4 = 0.3599;    //sin(0.3682) = 0.3599
                 8'd03: sin4 = 0.5350;    //sin(0.5645) = 0.5350
                 8'd04: sin4 = 0.6895;    //sin(0.7609) = 0.6895
                 8'd05: sin4 = 0.8176;    //sin(0.9572) = 0.8176
                 8'd06: sin4 = 0.9142;    //sin(1.1536) = 0.9142
                 8'd07: sin4 = 0.9757;    //sin(1.3499) = 0.9757

				default: sin4 = {N{1'b0}};
			endcase

 		end
	endfunction

    
	always @ (posedge clk)
		begin
			accumulator <= accumulator + 1'b1;
			case (quadrant)
				2'b00: sin <= {1'b1, sin4(t_even)};
				2'b01: sin <= {1'b1, sin4(t_odd)};
				2'b10: sin <= {1'b0, {N{1'b1}} - sin4(t_even)};
				2'b11: sin <= {1'b0, {N{1'b1}} - sin4(t_odd)};
			endcase
		end

endmodule