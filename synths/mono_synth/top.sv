module mono_synth (
    input  wire        clk,
    input  wire        rst,
    input  wire        byte_valid,
    input  wire [7:0]  byte_in,
    output wire [15:0] audio_sample,
    output wire        audio_valid
);

    localparam integer CLK_HZ              = 1_000_000;
    localparam integer AUDIO_HZ            = 44100;
    localparam integer LEGACY_ADSR_CLK_HZ  = 50_000_000;

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
    wire       sys_rt_valid;
    wire [7:0] sys_rt_byte;

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
        .sysex_overflow(sysex_overflow_unused),
        .sys_rt_valid(sys_rt_valid),
        .sys_rt_byte(sys_rt_byte)
    );

    wire note_on_evt  = midi_command_ready && (ch_message == 4'h9) && (msb != 7'd0);
    wire note_off_evt = midi_command_ready && (
        (ch_message == 4'h8) || ((ch_message == 4'h9) && (msb == 7'd0))
    );

    wire cc_evt_early = midi_command_ready && (ch_message == 4'hB);
    wire cc_all_notes_off = cc_evt_early && (lsb == 7'd123);
    wire cc_all_sound_off = cc_evt_early && (lsb == 7'd120);
    wire cc_reset_ctrl    = cc_evt_early && (lsb == 7'd121);
    wire cc121            = cc_reset_ctrl;
    wire midi_stop        = sys_rt_valid && (sys_rt_byte == 8'hFC);
    wire notes_off_evt    = cc_all_notes_off | midi_stop;

    wire [6:0] active_note;
    wire       gate;

    note_mono u_note_mono(
        .clk(clk),
        .rst(rst),
        .note_on(note_on_evt),
        .note_off(note_off_evt),
        .all_notes_off(notes_off_evt),
        .all_sound_off(cc_all_sound_off),
        .note(note_field),
        .out_note(active_note),
        .out_gate(gate)
    );

    wire [31:0] exp_value;
    lin2exp_t u_lin2exp(.data_in(msb), .data_out(exp_value));

    wire cc_evt = cc_evt_early;
    wire pitch_evt = midi_command_ready && (ch_message == 4'hE);

    wire        a_wr = cc_evt && (lsb == 7'd16);
    wire        d_wr = cc_evt && (lsb == 7'd17);
    wire        s_wr = cc_evt && (lsb == 7'd18);
    wire        r_wr = cc_evt && (lsb == 7'd19);
    wire        w_wr = cc_evt && (lsb == 7'd48);
    wire        p_wr = pitch_evt;
    wire        fcut_msb_wr = cc_evt && (lsb == 7'd74);
    wire        fcut_lsb_wr = cc_evt && (lsb == 7'd106);
    wire        fres_wr = cc_evt && (lsb == 7'd71);
    wire        fmode_wr = cc_evt && (lsb == 7'd22);
    wire        lfo_rate_wr = cc_evt && (lsb == 7'd49);
    wire        lfo_depth_wr = cc_evt && (lsb == 7'd50);
    wire        kfollow_wr = cc_evt && (lsb == 7'd51);
    wire        fa_wr = cc_evt && (lsb == 7'd24);
    wire        fd_wr = cc_evt && (lsb == 7'd25);
    wire        fs_wr = cc_evt && (lsb == 7'd26);
    wire        fr_wr = cc_evt && (lsb == 7'd27);
    wire        famt_wr = cc_evt && (lsb == 7'd28);

    wire [13:0] a_value = exp_value[13:0];
    wire [13:0] d_value = exp_value[13:0];
    wire [13:0] r_value = exp_value[13:0];
    wire [13:0] fa_value = exp_value[13:0];
    wire [13:0] fd_value = exp_value[13:0];
    wire [13:0] fr_value = exp_value[13:0];
    wire [13:0] pitch_value = {msb, lsb};

    wire        a_wr_eff = a_wr | cc121;
    wire        d_wr_eff = d_wr | cc121;
    wire        s_wr_eff = s_wr | cc121;
    wire        r_wr_eff = r_wr | cc121;
    wire        w_wr_eff = w_wr | cc121;
    wire        p_wr_eff = p_wr | cc121;
    wire        fres_wr_eff = fres_wr | cc121;
    wire        fmode_wr_eff = fmode_wr | cc121;
    wire        lfo_rate_wr_eff = lfo_rate_wr | cc121;
    wire        lfo_depth_wr_eff = lfo_depth_wr | cc121;
    wire        kfollow_wr_eff = kfollow_wr | cc121;
    wire        fa_wr_eff = fa_wr | cc121;
    wire        fd_wr_eff = fd_wr | cc121;
    wire        fs_wr_eff = fs_wr | cc121;
    wire        fr_wr_eff = fr_wr | cc121;
    wire        famt_wr_eff = famt_wr | cc121;

    wire [13:0] a_data_eff = cc121 ? 14'd7540 : a_value;
    wire [13:0] d_data_eff = cc121 ? 14'd7540 : d_value;
    wire [13:0] r_data_eff = cc121 ? 14'd7540 : r_value;
    wire [6:0]  s_data_eff = cc121 ? 7'd127 : msb;
    wire [6:0]  w_data_eff = cc121 ? 7'd0 : msb;
    wire [13:0] pitch_data_eff = cc121 ? 14'd8192 : pitch_value;
    wire [6:0]  fres_data_eff = cc121 ? 7'd0 : msb;
    wire [6:0]  fmode_data_eff = cc121 ? 7'd0 : msb;
    wire [6:0]  lfo_rate_data_eff = cc121 ? 7'd0 : msb;
    wire [6:0]  lfo_depth_data_eff = cc121 ? 7'd0 : msb;
    wire [6:0]  kfollow_data_eff = cc121 ? 7'd0 : msb;
    wire [13:0] fa_data_eff = cc121 ? 14'd7540 : fa_value;
    wire [13:0] fd_data_eff = cc121 ? 14'd7540 : fd_value;
    wire [13:0] fr_data_eff = cc121 ? 14'd7540 : fr_value;
    wire [6:0]  fs_data_eff = cc121 ? 7'd127 : msb;
    wire [6:0]  famt_data_eff = cc121 ? 7'd0 : msb;

    wire [13:0] attack14;
    wire [13:0] decay14;
    wire [13:0] release14;
    wire [6:0]  sustain7;
    wire [6:0]  wave7;
    wire [13:0] pitch14;
    wire [6:0]  fres7;
    wire [6:0]  fres_cc = 7'd127 - fres7;
    wire [6:0]  fmode7;
    wire [6:0]  lfo_rate7;
    wire [6:0]  lfo_depth7;
    wire [6:0]  kfollow7;
    wire [13:0] f_attack14;
    wire [13:0] f_decay14;
    wire [13:0] f_release14;
    wire [6:0]  f_sustain7;
    wire [6:0]  f_env_amt7;

    reg14 #(.INIT(14'd7540)) u_a_reg(.clk(clk), .rst(1'b0), .wr(a_wr_eff), .data(a_data_eff), .data_out(attack14));
    reg14 #(.INIT(14'd7540)) u_d_reg(.clk(clk), .rst(1'b0), .wr(d_wr_eff), .data(d_data_eff), .data_out(decay14));
    reg14 #(.INIT(14'd7540)) u_r_reg(.clk(clk), .rst(1'b0), .wr(r_wr_eff), .data(r_data_eff), .data_out(release14));
    reg7  #(.INIT(7'd127))   u_s_reg(.clk(clk), .rst(1'b0), .wr(s_wr_eff), .data(s_data_eff), .data_out(sustain7));
    reg7  #(.INIT(7'd0))     u_w_reg(.clk(clk), .rst(1'b0), .wr(w_wr_eff), .data(w_data_eff), .data_out(wave7));
    reg14 #(.INIT(14'd8192)) u_pitch_reg(.clk(clk), .rst(1'b0), .wr(p_wr_eff), .data(pitch_data_eff), .data_out(pitch14));

    // CC74/106: no rst — survives VST Hello (synthOnSessionStart pulses rst for voice only).
    // CC74 alone duplicates into LSB (7-bit knob); CC106 overwrites fine bits after.
    reg [13:0] fcut14;

    initial fcut14 = 14'd8192;

    always @(posedge clk) begin
        if (cc121)
            fcut14 <= 14'd8192;
        else if (fcut_msb_wr) begin
            fcut14[13:7] <= msb;
            fcut14[6:0]  <= msb;
        end else if (fcut_lsb_wr)
            fcut14[6:0] <= msb;
    end

    reg7  #(.INIT(7'd0))     u_fres_reg(.clk(clk), .rst(1'b0), .wr(fres_wr_eff), .data(fres_data_eff), .data_out(fres7));
    reg7  #(.INIT(7'd0))     u_fmode_reg(.clk(clk), .rst(1'b0), .wr(fmode_wr_eff), .data(fmode_data_eff), .data_out(fmode7));
    reg7  #(.INIT(7'd0))     u_lfo_rate_reg(.clk(clk), .rst(1'b0), .wr(lfo_rate_wr_eff), .data(lfo_rate_data_eff), .data_out(lfo_rate7));
    reg7  #(.INIT(7'd0))     u_lfo_depth_reg(.clk(clk), .rst(1'b0), .wr(lfo_depth_wr_eff), .data(lfo_depth_data_eff), .data_out(lfo_depth7));
    reg7  #(.INIT(7'd0))     u_kfollow_reg(.clk(clk), .rst(1'b0), .wr(kfollow_wr_eff), .data(kfollow_data_eff), .data_out(kfollow7));
    reg14 #(.INIT(14'd7540)) u_fa_reg(.clk(clk), .rst(1'b0), .wr(fa_wr_eff), .data(fa_data_eff), .data_out(f_attack14));
    reg14 #(.INIT(14'd7540)) u_fd_reg(.clk(clk), .rst(1'b0), .wr(fd_wr_eff), .data(fd_data_eff), .data_out(f_decay14));
    reg14 #(.INIT(14'd7540)) u_fr_reg(.clk(clk), .rst(1'b0), .wr(fr_wr_eff), .data(fr_data_eff), .data_out(f_release14));
    reg7  #(.INIT(7'd127))   u_fs_reg(.clk(clk), .rst(1'b0), .wr(fs_wr_eff), .data(fs_data_eff), .data_out(f_sustain7));
    reg7  #(.INIT(7'd0))     u_famt_reg(.clk(clk), .rst(1'b0), .wr(famt_wr_eff), .data(famt_data_eff), .data_out(f_env_amt7));

    reg [31:0] audio_acc;
    reg        audio_tick;

    always @(posedge clk) begin
        if (rst) begin
            audio_acc  <= 32'd0;
            audio_tick <= 1'b0;
        end else begin
            audio_tick <= 1'b0;
            if (audio_acc + AUDIO_HZ >= CLK_HZ) begin
                audio_acc  <= audio_acc + AUDIO_HZ - CLK_HZ;
                audio_tick <= 1'b1;
            end else begin
                audio_acc <= audio_acc + AUDIO_HZ;
            end
        end
    end

    // Same LEGACY rate scale as mono_voice (LEGACY_RATE_INPUT=1).
    wire [31:0] f_attack_raw   = {{18{1'b0}}, f_attack14};
    wire [31:0] f_decay_raw    = {{18{1'b0}}, f_decay14};
    wire [31:0] f_release_raw  = {{18{1'b0}}, f_release14};
    wire [63:0] f_attack_wide  = f_attack_raw * LEGACY_ADSR_CLK_HZ;
    wire [63:0] f_decay_wide   = f_decay_raw * LEGACY_ADSR_CLK_HZ;
    wire [63:0] f_release_wide = f_release_raw * LEGACY_ADSR_CLK_HZ;
    wire [31:0] f_attack_rate  = f_attack_wide / AUDIO_HZ;
    wire [31:0] f_decay_rate   = f_decay_wide / AUDIO_HZ;
    wire [31:0] f_release_rate = f_release_wide / AUDIO_HZ;
    wire [31:0] f_sustain_level = {f_sustain7, 25'b0};

    wire [31:0] filt_adsr;
    adsr #(
        .ACCUM_BITS(32),
        .RATE_BITS(32),
        .CV_BITS(16)
    ) u_filt_adsr(
        .clk(clk),
        .rst(rst),
        .tick(audio_tick),
        .gate(gate),
        .note_on(note_on_evt),
        .sound_off(cc_all_sound_off),
        .attack_rate(f_attack_rate),
        .decay_rate(f_decay_rate),
        .sustain_level(f_sustain_level),
        .release_rate(f_release_rate),
        .signal_out(filt_adsr)
    );

    wire [7:0] lfo_sig;
    wire [13:0] fcut14_eff;

    lfo #(
        .CLK_HZ(CLK_HZ)
    ) u_lfo(
        .clk(clk),
        .rst(rst),
        .rate7(lfo_rate7),
        .sig_out(lfo_sig)
    );

    svf_fcut_mix u_fcut_mix(
        .manual14(fcut14),
        .note(active_note),
        .keyfollow7(kfollow7),
        .lfo_sig(lfo_sig),
        .lfo_depth7(lfo_depth7),
        .env_u16(filt_adsr[31:16]),
        .env_amount7(f_env_amt7),
        .fcut14_out(fcut14_eff)
    );

    wire [17:0] svf_f;
    wire [17:0] svf_q;
    wire [1:0]  svf_mode = fmode7[6:5];
    wire [2:0]  wave_form = (wave7[6:4] > 3'd5) ? 3'd5 : wave7[6:4];

    svf_cutoff14_to_f u_svf_fc(.idx(fcut14_eff), .f(svf_f));
    svf_cc_to_q u_svf_fq(.cc(fres_cc), .q(svf_q));

    wire [31:0] attack_rate  = {{18{1'b0}}, attack14};
    wire [31:0] decay_rate   = {{18{1'b0}}, decay14};
    wire [31:0] release_rate = {{18{1'b0}}, release14};
    wire [31:0] sustain_level = {sustain7, 25'b0};

    wire [15:0] voice_out;
    wire        voice_valid;

    mono_voice #(
        .CLK_HZ(CLK_HZ),
        .OUT_WIDTH(16),
        .SAMPLE_CLK_FREQ(AUDIO_HZ),
        .LEGACY_RATE_INPUT(1),
        .USE_SVF(1)
    ) u_voice(
        .clk(clk),
        .rst(rst),
        .gate(gate),
        .note_on(note_on_evt),
        .sound_off(cc_all_sound_off),
        .note(active_note),
        .pitch(pitch14),
        .lfo_sig(8'd128),
        .lfo_depth(7'd0),
        .lfo_depth_fine(7'd0),
        .wave_form(wave_form),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .svf_f(svf_f),
        .svf_q(svf_q),
        .svf_mode(svf_mode),
        .audio_valid(voice_valid),
        .signal_out(voice_out)
    );

    assign audio_sample = voice_out;
    assign audio_valid  = voice_valid;

endmodule
