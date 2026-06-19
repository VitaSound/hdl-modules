// Step 3: index DDS[29:27] -> 4 LUT passes per DDS period
module step3_idx_29_27(
    input wire CLK,
    input wire [31:0] DDS,
    output reg [31:0] out_sine
);
    wire [2:0] table_idx = DDS[29:27];

    always @(posedge CLK) begin
        case (table_idx)
            3'b000: out_sine <= 0.0000 * (32'hFFFFFFFF / 2);
            3'b001: out_sine <= 0.1710 * (32'hFFFFFFFF / 2);
            3'b010: out_sine <= 0.3599 * (32'hFFFFFFFF / 2);
            3'b011: out_sine <= 0.5350 * (32'hFFFFFFFF / 2);
            3'b100: out_sine <= 0.6895 * (32'hFFFFFFFF / 2);
            3'b101: out_sine <= 0.8176 * (32'hFFFFFFFF / 2);
            3'b110: out_sine <= 0.9142 * (32'hFFFFFFFF / 2);
            3'b111: out_sine <= 0.9757 * (32'hFFFFFFFF / 2);
            default: out_sine <= 0;
        endcase
    end
endmodule
