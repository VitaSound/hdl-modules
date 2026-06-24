// Chamberlin state-variable filter: HP, BP, LP, BR in one tick.
// f = 2*sin(pi*Fc/Fs), q = 1/Q (signed 18-bit coeffs, Q17 scaling in multiplies).
module svf (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   tick,
    input  wire signed [17:0]     f,
    input  wire signed [17:0]     q,
    input  wire signed [11:0]     in,
    output reg  signed [17:0]     hp,
    output reg  signed [17:0]     bp,
    output reg  signed [17:0]     lp,
    output reg  signed [17:0]     br
);

    localparam signed [35:0] STATE_FLUSH_THRESH = 36'sd1;

    reg signed [35:0] z1;
    reg signed [35:0] z2;

    wire signed [17:0] in18 = {{6{in[11]}}, in};
    wire signed [35:0] bp_scaled = z1 >>> 17;
    wire signed [35:0] multq    = bp_scaled * q;
    wire signed [35:0] in36     = {{18{in18[17]}}, in18, 18'b0};
    wire signed [35:0] hp_full   = in36 - multq - z2;
    wire signed [17:0] hp_next   = hp_full >>> 17;
    wire signed [35:0] f_hp      = f * hp_next;
    wire signed [35:0] f_bp      = f * bp_scaled;
    wire signed [35:0] z1_next   = f_hp + z1;
    wire signed [35:0] z2_next   = f_bp + z2;

    wire signed [17:0] lp_next = z2_next >>> 18;
    wire signed [17:0] bp_next = z1_next >>> 18;
    wire signed [18:0] br_sum  = hp_next + lp_next;
    wire signed [17:0] br_next =
        (br_sum > 19'sd131071)  ? 18'sd131071 :
        (br_sum < -19'sd131072) ? -18'sd131072 :
        br_sum[17:0];

    wire signed [35:0] z1_flush =
        (z1_next < STATE_FLUSH_THRESH && z1_next > -STATE_FLUSH_THRESH)
            ? 36'sd0 : z1_next;
    wire signed [35:0] z2_flush =
        (z2_next < STATE_FLUSH_THRESH && z2_next > -STATE_FLUSH_THRESH)
            ? 36'sd0 : z2_next;

    always @(posedge clk) begin
        if (rst) begin
            z1 <= 36'sd0;
            z2 <= 36'sd0;
            hp  <= 18'sd0;
            bp  <= 18'sd0;
            lp  <= 18'sd0;
            br  <= 18'sd0;
        end else if (tick) begin
            z1 <= z1_flush;
            z2 <= z2_flush;
            hp  <= hp_next;
            bp  <= bp_next;
            lp  <= lp_next;
            br  <= br_next;
        end
    end

endmodule
