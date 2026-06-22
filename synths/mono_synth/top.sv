module mono_synth (
    input  wire        clk,
    input  wire        rst,
    input  wire        byte_valid,
    input  wire [7:0]  byte_in,
    output wire [15:0] audio_sample
);

    localparam integer CLK_HZ = 1_000_000;

    wire       midi_command_ready;
    wire [3:0] ch_message;
    wire [3:0] chan;
    wire [6:0] note_field;
    wire [6:0] lsb;
    wire [6:0] msb;

    wire sysex_byte_valid_unused;
    wire [7:0] sysex_byte_unused;
    wire sysex_done_unused;
    wire sysex_overflow_unused;

    midi_in u_midi_in(
        .clk(clk),
        .rst(rst),
        .byte_valid(byte_valid),
        .byte_in(byte_in),
        .midi_command_ready(midi_command_ready),
        .ch_message(ch_message),
        .chan(chan),
        .note(note_field),
        .lsb(lsb),
        .msb(msb),
        .sysex_byte_valid(sysex_byte_valid_unused),
        .sysex_byte(sysex_byte_unused),
        .sysex_done(sysex_done_unused),
        .sysex_overflow(sysex_overflow_unused)
    );

    wire note_on_evt  = midi_command_ready && (ch_message == 4'h9) && (msb != 7'd0);
    wire note_off_evt = midi_command_ready && (
        (ch_message == 4'h8) || ((ch_message == 4'h9) && (msb == 7'd0))
    );

    wire [6:0] active_note;
    wire       gate;

    note_mono u_note_mono(
        .clk(clk),
        .rst(rst),
        .note_on(note_on_evt),
        .note_off(note_off_evt),
        .note(note_field),
        .out_note(active_note),
        .out_gate(gate)
    );

    wire [31:0] exp_value;
    lin2exp_t u_lin2exp(.data_in(msb), .data_out(exp_value));

    wire cc_evt = midi_command_ready && (ch_message == 4'hB);
    wire pitch_evt = midi_command_ready && (ch_message == 4'hE);

    wire        a_wr = cc_evt && (lsb == 7'd16);
    wire        d_wr = cc_evt && (lsb == 7'd17);
    wire        s_wr = cc_evt && (lsb == 7'd18);
    wire        r_wr = cc_evt && (lsb == 7'd19);
    wire        w_wr = cc_evt && (lsb == 7'd48);
    wire        p_wr = pitch_evt;

    wire [13:0] a_value = exp_value[13:0];
    wire [13:0] d_value = exp_value[13:0];
    wire [13:0] r_value = exp_value[13:0];
    wire [13:0] pitch_value = {msb, lsb};

    wire [13:0] attack14;
    wire [13:0] decay14;
    wire [13:0] release14;
    wire [6:0]  sustain7;
    wire [6:0]  wave7;
    wire [13:0] pitch14;

    reg14 #(.INIT(14'd7540)) u_a_reg(.clk(clk), .rst(rst), .wr(a_wr), .data(a_value), .data_out(attack14));
    reg14 #(.INIT(14'd7540)) u_d_reg(.clk(clk), .rst(rst), .wr(d_wr), .data(d_value), .data_out(decay14));
    reg14 #(.INIT(14'd7540)) u_r_reg(.clk(clk), .rst(rst), .wr(r_wr), .data(r_value), .data_out(release14));
    reg7  #(.INIT(7'd127))   u_s_reg(.clk(clk), .rst(rst), .wr(s_wr), .data(msb), .data_out(sustain7));
    reg7  #(.INIT(7'd0))     u_w_reg(.clk(clk), .rst(rst), .wr(w_wr), .data(msb), .data_out(wave7));
    reg14 #(.INIT(14'd8192)) u_pitch_reg(.clk(clk), .rst(rst), .wr(p_wr), .data(pitch_value), .data_out(pitch14));

    wire [31:0] attack_rate  = {{18{1'b0}}, attack14};
    wire [31:0] decay_rate   = {{18{1'b0}}, decay14};
    wire [31:0] release_rate = {{18{1'b0}}, release14};
    wire [31:0] sustain_level = {sustain7, 25'b0};

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
        .pitch(pitch14),
        .lfo_sig(8'd128),
        .lfo_depth(7'd0),
        .lfo_depth_fine(7'd0),
        .wave_form(wave7[2:0]),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .signal_out(voice_out)
    );

    assign audio_sample = voice_out;

endmodule
