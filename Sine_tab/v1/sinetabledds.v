module sinetabledds(
		
	input wire CLK,
    input wire RESET,

    input wire [31:0] DDS,               
    output reg [31:0] out_sine 
);

	wire [2:0] table_idx;

	assign table_idx = DDS[31:29];

	always @ (posedge CLK)
	begin
		case (table_idx) 
			3'b000: out_sine <= 0.0000 * 32'hFFFFFFFF;    //sin(0.0000) = 0.0000
			3'b001: out_sine <= 0.1710 * 32'hFFFFFFFF;    //sin(0.1718) = 0.1710
			3'b010: out_sine <= 0.3599 * 32'hFFFFFFFF;    //sin(0.3682) = 0.3599
			3'b011: out_sine <= 0.5350 * 32'hFFFFFFFF;    //sin(0.5645) = 0.5350
			3'b100: out_sine <= 0.6895 * 32'hFFFFFFFF;    //sin(0.7609) = 0.6895
			3'b101: out_sine <= 0.8176 * 32'hFFFFFFFF;    //sin(0.9572) = 0.8176
			3'b110: out_sine <= 0.9142 * 32'hFFFFFFFF;    //sin(1.1536) = 0.9142
			3'b111: out_sine <= 0.9757 * 32'hFFFFFFFF;    //sin(1.3499) = 0.9757

			default: out_sine <= 0.0000 * 32'hFFFFFFFF;
		endcase
	end

endmodule
