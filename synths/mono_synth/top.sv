module mono_synth (
    input  wire        clk,
    input  wire        rst,
    input  wire        note_on,
    input  wire        note_off,
    input  wire [6:0]  note,
    input  wire        cc_wr,
    input  wire [6:0]  cc_num,
    input  wire [6:0]  cc_val,
    input  wire        pitch_wr,
    input  wire [13:0] pitch_val,
    output wire [15:0] audio_sample
);

    localparam integer CLK_HZ = 960_000;

    wire [6:0] active_note;
    wire       gate;

    note_mono u_note_mono(
        .clk(clk),
        .rst(rst),
        .note_on(note_on),
        .note_off(note_off),
        .note(note),
        .out_note(active_note),
        .out_gate(gate)
    );

    wire [31:0] exp_value;
    lin2exp_t u_lin2exp(.data_in(cc_val), .data_out(exp_value));

    wire        a_wr = cc_wr && (cc_num == 7'd16);
    wire        d_wr = cc_wr && (cc_num == 7'd17);
    wire        s_wr = cc_wr && (cc_num == 7'd18);
    wire        r_wr = cc_wr && (cc_num == 7'd19);
    wire        w_wr = cc_wr && (cc_num == 7'd48);

    wire [13:0] a_value = exp_value[13:0];
    wire [13:0] d_value = exp_value[13:0];
    wire [13:0] r_value = exp_value[13:0];
    wire [6:0]  s_value = cc_val;
    wire [6:0]  w_value = cc_val;

    wire [13:0] attack14;
    wire [13:0] decay14;
    wire [13:0] release14;
    wire [6:0]  sustain7;
    wire [6:0]  wave7;

    reg14 #(.INIT(14'd7540)) u_a_reg(.clk(clk), .rst(rst), .wr(a_wr), .data(a_value), .data_out(attack14));
    reg14 #(.INIT(14'd7540)) u_d_reg(.clk(clk), .rst(rst), .wr(d_wr), .data(d_value), .data_out(decay14));
    reg14 #(.INIT(14'd7540)) u_r_reg(.clk(clk), .rst(rst), .wr(r_wr), .data(r_value), .data_out(release14));
    reg7  #(.INIT(7'd127))   u_s_reg(.clk(clk), .rst(rst), .wr(s_wr), .data(s_value), .data_out(sustain7));
    reg7  #(.INIT(7'd0))     u_w_reg(.clk(clk), .rst(rst), .wr(w_wr), .data(w_value), .data_out(wave7));

    wire [13:0] pitch;
    reg14 #(.INIT(14'd8192)) u_pitch_reg(.clk(clk), .rst(rst), .wr(pitch_wr), .data(pitch_val), .data_out(pitch));

    wire [3:0] adsr_a;
    wire [3:0] adsr_d;
    wire [3:0] adsr_s;
    wire [3:0] adsr_r;

    adsr_regs_to_ctrl4 u_adsr_map(
        .attack14(attack14),
        .decay14(decay14),
        .release14(release14),
        .sustain7(sustain7),
        .a(adsr_a),
        .d(adsr_d),
        .s(adsr_s),
        .r(adsr_r)
    );

    wire [15:0] voice_out;

    mono_voice #(
        .CLK_HZ(CLK_HZ),
        .OUT_WIDTH(16),
        .SAMPLE_CLK_FREQ(48000)
    ) u_voice(
        .clk(clk),
        .rst(rst),
        .gate(gate),
        .note(active_note),
        .pitch(pitch),
        .lfo_sig(8'd128),
        .lfo_depth(7'd0),
        .lfo_depth_fine(7'd0),
        .wave_form(wave7[2:0]),
        .a(adsr_a),
        .d(adsr_d),
        .s(adsr_s),
        .r(adsr_r),
        .signal_out(voice_out)
    );

    assign audio_sample = voice_out;

endmodule
