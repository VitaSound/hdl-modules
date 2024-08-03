module sinetabledds(
		
	input wire CLK,
    input wire RESET,

    input wire [31:0] DDS,               
    output wire [31:0] out_sine 
);

	reg [30:0] table_sine;

	wire [2:0] table_idx;

	assign table_idx = (!DDS[30]) ? DDS[29:27] : 32'hFFFFFFFF - DDS[29:27];

	assign out_sine = (!DDS[31]) ? (32'hFFFFFFFF / 2) + table_sine : (32'hFFFFFFFF / 2) - table_sine;

	always @ (posedge CLK)
	begin
		case (table_idx) 
			3'b000: table_sine <= 0.0000 * (32'hFFFFFFFF / 2);    //sin(0.0000) = 0.0000
			3'b001: table_sine <= 0.1710 * (32'hFFFFFFFF / 2);    //sin(0.1718) = 0.1710
			3'b010: table_sine <= 0.3599 * (32'hFFFFFFFF / 2);    //sin(0.3682) = 0.3599
			3'b011: table_sine <= 0.5350 * (32'hFFFFFFFF / 2);    //sin(0.5645) = 0.5350
			3'b100: table_sine <= 0.6895 * (32'hFFFFFFFF / 2);    //sin(0.7609) = 0.6895
			3'b101: table_sine <= 0.8176 * (32'hFFFFFFFF / 2);    //sin(0.9572) = 0.8176
			3'b110: table_sine <= 0.9142 * (32'hFFFFFFFF / 2);    //sin(1.1536) = 0.9142
			3'b111: table_sine <= 0.9757 * (32'hFFFFFFFF / 2);    //sin(1.3499) = 0.9757

			default: table_sine <= 0.0000 * (32'hFFFFFFFF / 2);
		endcase
	end

endmodule
