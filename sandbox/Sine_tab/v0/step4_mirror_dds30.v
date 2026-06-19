// Step 4: quarter mirror via DDS[30]; output still positive-only (no DDS[31] sign yet)
module step4_mirror_dds30(
    input wire CLK,
    input wire [31:0] DDS,
    output reg [31:0] out_sine
);
    reg [30:0] table_sine;
    wire [2:0] table_idx;

    assign table_idx = (!DDS[30]) ? DDS[29:27] : 32'hFFFFFFFF - DDS[29:27];
    assign out_sine = table_sine;

    always @(posedge CLK) begin
        case (table_idx)
            3'b000: table_sine <= 0.0000 * (32'hFFFFFFFF / 2);
            3'b001: table_sine <= 0.1710 * (32'hFFFFFFFF / 2);
            3'b010: table_sine <= 0.3599 * (32'hFFFFFFFF / 2);
            3'b011: table_sine <= 0.5350 * (32'hFFFFFFFF / 2);
            3'b100: table_sine <= 0.6895 * (32'hFFFFFFFF / 2);
            3'b101: table_sine <= 0.8176 * (32'hFFFFFFFF / 2);
            3'b110: table_sine <= 0.9142 * (32'hFFFFFFFF / 2);
            3'b111: table_sine <= 0.9757 * (32'hFFFFFFFF / 2);
            default: table_sine <= 0;
        endcase
    end
endmodule
