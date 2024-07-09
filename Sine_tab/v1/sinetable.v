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

	function [N-1:0] sin4;
		input [N:0] t4;
		begin
			case (t4)
				`include "sin.v"  //"sin.vi"
				default: sin4 = {N{1'b0}};
			endcase
//			`include "sin_if.vi"   // !!!вот эта строка вызывает проблему
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