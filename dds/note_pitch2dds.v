module note_pitch2dds #(
    parameter CLK_HZ = 50_000_000
)(clk, note, pitch, lfo_sig, lfo_depth, lfo_depth_fine, adder);
    input  wire clk;
    input  wire [6:0] note;
    input  wire [13:0] pitch;
    input  wire [7:0] lfo_sig;
    input  wire [6:0] lfo_depth;
    input  wire [6:0] lfo_depth_fine;
    output reg  [31:0] adder;

    wire signed [7:0] s_note_local = note;
    wire signed [16:0] s_wide_note = s_note_local <<< 8;

    wire signed [14:0] s_pitch_local = pitch;
    wire signed [16:0] s_pitch = s_pitch_local - 14'd8192;

    wire signed [17:0] scaled_pitch = (s_pitch <<< 3) + (s_pitch <<< 2);
    wire signed [17:0] res_pitch = (scaled_pitch >>> 5);

    wire signed [9:0] s_lfo = lfo_sig - 8'd128;
    wire signed [9:0] s_lfo_depth = lfo_depth;
    wire signed [9:0] s_lfo_depth_fine = lfo_depth_fine;

    wire signed [16:0] s_res_lfo = s_lfo_depth * s_lfo;
    wire signed [16:0] s_res_lfo_fine = s_lfo_depth_fine * s_lfo;

    wire signed [19:0] s_result_note = s_wide_note + res_pitch + s_res_lfo + (s_res_lfo_fine >>> 7);
    wire [19:0] result_note = (s_result_note > 20'd0) ? s_result_note[19:0] : 20'd0;

    wire [8:0] note_int = result_note[19:8];
    wire [7:0] note_frac = result_note[7:0];

    initial
        adder <= 32'd0;

    wire [31:0] adder_by_table;
    wire [31:0] adder_by_table1;

    note2dds #(.CLK_HZ(CLK_HZ)) note2dds_table1(
        .clk(clk),
        .note(note_int),
        .adder(adder_by_table)
    );

    note2dds #(.CLK_HZ(CLK_HZ)) note2dds_table2(
        .clk(clk),
        .note(note_int + 9'd1),
        .adder(adder_by_table1)
    );

    wire [40:0] adder_sum = adder_by_table * (9'd255 - {1'b0, note_frac})
                          + adder_by_table1 * {1'b0, note_frac};

    always @(posedge clk)
        adder <= adder_sum >> 8;
endmodule
