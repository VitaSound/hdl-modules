
module sinetable(
		
	input wire CLK,
    input wire RESET,

    input wire [31:0] DDS,               
    output reg [31:0] DDSout_dds31, 

    
	parameter N = 7;         // размерность функции четверть-периода синуса
    
	wire [N-1:0] angle = 0;  // значение t внутри квадранта
	wire [N:0] t_even = 0;
	wire [N:0] t_odd = 0;    // значения t4 для чётных и нечётных квадрантов
	wire [1:0] quadrant = 0; // номер квадранта
);
	
	function [N-1:0] sin4;
		input [N:0] t4;     // t4 
		begin
				
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

    
	always @ (posedge CLK)
		begin
			//accumulator <= accumulator + 1'b1;
			case (quadrant)
				//   DDSout_dds31 <= DDS;
				// каккая разрядность исходя из нашего счётчика 2'b001
				2'b00: DDSout_dds31 <= {1'b1, sin4(t_even)};
				2'b01: DDSout_dds31 <= {1'b1, sin4(t_odd)};
				2'b10: DDSout_dds31 <= {1'b0, {N{1'b1}} - sin4(t_even)};
				2'b11: DDSout_dds31 <= {1'b0, {N{1'b1}} - sin4(t_odd)};
			endcase
		end

endmodule
