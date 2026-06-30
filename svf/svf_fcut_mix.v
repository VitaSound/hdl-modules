module svf_fcut_mix #(
    parameter REF_NOTE = 7'd60
)(
    input  wire [13:0] manual14,
    input  wire [6:0]  note,
    input  wire [6:0]  keyfollow7,
    input  wire [7:0]  lfo_sig,
    input  wire [6:0]  lfo_depth7,
    input  wire [15:0] env_u16,
    input  wire [6:0]  env_amount7,
    output wire [13:0] fcut14_out
);

    wire [13:0] note_idx;
    wire [13:0] ref_idx;

    note_fcut_lut u_note_lut(.note(note), .idx(note_idx));
    note_fcut_lut u_ref_lut(.note(REF_NOTE), .idx(ref_idx));

    wire signed [14:0] note_delta =
        $signed({1'b0, note_idx}) - $signed({1'b0, ref_idx});

    wire signed [21:0] track_wide = note_delta * $signed({1'b0, keyfollow7});
    wire signed [14:0] track = track_wide >>> 7;

    wire signed [9:0]  lfo_bipolar = $signed({2'b0, lfo_sig}) - 10'sd128;
    wire signed [16:0] lfo_wide = lfo_bipolar * $signed({1'b0, lfo_depth7});
    wire signed [14:0] lfo_mod = lfo_wide >>> 7;

    wire signed [23:0] env_wide = $signed({8'b0, env_u16}) * $signed({1'b0, env_amount7});
    wire signed [16:0] env_mod = env_wide >>> 7;

    wire signed [22:0] sum_wide =
        $signed({9'b0, manual14}) + track + lfo_mod + env_mod;

    wire signed [15:0] sum_clamped =
        (sum_wide < 23'sd0) ? 16'sd0 :
        (sum_wide > 23'sd16383) ? 16'sd16383 : sum_wide[15:0];

    assign fcut14_out = sum_clamped[13:0];

endmodule
