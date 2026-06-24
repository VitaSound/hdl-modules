// Chamberlin state-variable filter: HP, BP, LP, notch in one tick.
// f = 2*sin(pi*Fc/Fs), q = 1/Q (signed 18-bit coeffs, Q17 scaling in multiplies).
// Audio ports signed 16-bit; in36 = sign_extend(in) << IN_SHIFT (default 14).
module svf #(
    parameter IN_SHIFT = 14
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   tick,
    input  wire signed [17:0]     f,
    input  wire signed [17:0]     q,
    input  wire signed [15:0]     in,
    output reg  signed [15:0]     hp,
    output reg  signed [15:0]     bp,
    output reg  signed [15:0]     lp,
    output reg  signed [15:0]     notch
);

    localparam signed [35:0] STATE_FLUSH_THRESH = 36'sd1;

    reg signed [35:0] z1;
    reg signed [35:0] z2;

    function signed [15:0] sat16;
        input signed [35:0] v;
        begin
            if (v > 36'sd32767)
                sat16 = 16'sd32767;
            else if (v < -36'sd32768)
                sat16 = -16'sd32768;
            else
                sat16 = v[15:0];
        end
    endfunction

    function signed [17:0] sat18;
        input signed [35:0] v;
        begin
            if (v > 36'sd131071)
                sat18 = 18'sd131071;
            else if (v < -36'sd131072)
                sat18 = -18'sd131072;
            else
                sat18 = v[17:0];
        end
    endfunction

    wire signed [35:0] bp_scaled = z1 >>> 17;
    wire signed [35:0] multq    = bp_scaled * q;
    wire signed [35:0] in36     = {{(20 - IN_SHIFT){in[15]}}, in, {IN_SHIFT{1'b0}}};
    wire signed [35:0] hp_full   = in36 - multq - z2;
    wire signed [17:0] hp_int    = sat18(hp_full >>> 17);
    wire signed [35:0] f_hp      = f * hp_int;
    wire signed [35:0] f_bp      = f * bp_scaled;
    wire signed [35:0] z1_next   = f_hp + z1;
    wire signed [35:0] z2_next   = f_bp + z2;

    wire signed [15:0] hp_next = sat16(hp_full >>> IN_SHIFT);
    wire signed [15:0] lp_next = sat16(z2_next >>> IN_SHIFT);
    wire signed [15:0] bp_next = sat16(z1_next >>> IN_SHIFT);
    wire signed [36:0] notch_sum = (hp_full >>> IN_SHIFT) + (z2_next >>> IN_SHIFT);
    wire signed [15:0] notch_next =
        (notch_sum > 37'sd32767)  ? 16'sd32767 :
        (notch_sum < -37'sd32768) ? -16'sd32768 :
        notch_sum[15:0];

    wire signed [35:0] z1_flush =
        (z1_next > 36'sh7FFFFFFFF) ? 36'sh7FFFFFFFF :
        (z1_next < -36'sh800000000) ? -36'sh800000000 :
        (z1_next < STATE_FLUSH_THRESH && z1_next > -STATE_FLUSH_THRESH)
            ? 36'sd0 : z1_next;
    wire signed [35:0] z2_flush =
        (z2_next > 36'sh7FFFFFFFF) ? 36'sh7FFFFFFFF :
        (z2_next < -36'sh800000000) ? -36'sh800000000 :
        (z2_next < STATE_FLUSH_THRESH && z2_next > -STATE_FLUSH_THRESH)
            ? 36'sd0 : z2_next;

    always @(posedge clk) begin
        if (rst) begin
            z1 <= 36'sd0;
            z2 <= 36'sd0;
            hp  <= 16'sd0;
            bp  <= 16'sd0;
            lp  <= 16'sd0;
            notch <= 16'sd0;
        end else if (tick) begin
            z1 <= z1_flush;
            z2 <= z2_flush;
            hp  <= hp_next;
            bp  <= bp_next;
            lp  <= lp_next;
            notch <= notch_next;
        end
    end

endmodule
