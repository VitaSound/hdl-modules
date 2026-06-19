module dds2sin #(
    parameter WIDTH    = 32,
    parameter LUT_BITS = 3
)(signal_in, signal_out);
    input wire [(WIDTH - 1):0] signal_in;
    output wire [(WIDTH - 1):0] signal_out;

    localparam [(WIDTH - 1):0] MID = {1'b0, {(WIDTH - 1){1'b1}}};
    localparam                         LUT_ENTRIES = (1 << LUT_BITS);
    localparam [LUT_BITS - 1:0]        LUT_MAX     = LUT_ENTRIES - 1;

    wire [LUT_BITS - 1:0] raw_idx   = signal_in[WIDTH - 3 : WIDTH - 2 - LUT_BITS];
    wire [LUT_BITS - 1:0] table_idx = signal_in[WIDTH - 2] ? (LUT_MAX - raw_idx) : raw_idx;

    function automatic [(WIDTH - 2):0] quarter_sin;
        input [LUT_BITS - 1:0] idx;
        integer i;
        real phase, mid_r;
        begin
            mid_r = (2.0 ** (WIDTH - 1)) - 1.0;
            i     = idx;
            phase = i * 1.5707963267948966 / (LUT_ENTRIES - 1);
            quarter_sin = $rtoi($sin(phase) * mid_r);
        end
    endfunction

    wire [(WIDTH - 2):0] table_sine = quarter_sin(table_idx);

    assign signal_out = signal_in[WIDTH - 1]
        ? (MID - {{1'b0}, table_sine})
        : (MID + {{1'b0}, table_sine});
endmodule
