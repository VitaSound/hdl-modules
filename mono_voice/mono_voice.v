module mono_voice #(
    parameter CLK_HZ           = 1_000_000,
    parameter OUT_WIDTH        = 16,
    parameter DDS_WIDTH        = 32,
    parameter SAMPLE_CLK_FREQ  = 44100,
    parameter ADSR_RATE_BITS   = 32,
    parameter LEGACY_ADSR_CLK_HZ = 50_000_000,
    parameter LEGACY_RATE_INPUT  = 0,
    parameter PWM_DUTY         = 7'd64,
    parameter USE_SVF          = 0
)(clk, rst, gate, note_on,
  note, pitch, lfo_sig, lfo_depth, lfo_depth_fine, wave_form,
  attack_rate, decay_rate, sustain_level, release_rate,
  svf_f, svf_q, svf_mode,
  audio_valid,
  signal_out);

    input  wire clk, rst, gate, note_on;
    input  wire [6:0] note;
    input  wire [13:0] pitch;
    input  wire [7:0] lfo_sig;
    input  wire [6:0] lfo_depth;
    input  wire [6:0] lfo_depth_fine;
    input  wire [2:0] wave_form;
    input  wire [ADSR_RATE_BITS - 1:0] attack_rate;
    input  wire [ADSR_RATE_BITS - 1:0] decay_rate;
    input  wire [ADSR_RATE_BITS - 1:0] sustain_level;
    input  wire [ADSR_RATE_BITS - 1:0] release_rate;
    input  wire [17:0] svf_f;
    input  wire [17:0] svf_q;
    input  wire [1:0]  svf_mode;
    output wire        audio_valid;
    output wire [OUT_WIDTH - 1:0] signal_out;

    localparam SAW      = 3'b000;
    localparam SQUARE   = 3'b001;
    localparam TRIANGLE = 3'b010;
    localparam SINE     = 3'b011;
    localparam RAMP     = 3'b100;
    localparam PWM_WAVE = 3'b101;

    wire [63:0] attack_wide  = attack_rate * LEGACY_ADSR_CLK_HZ;
    wire [63:0] decay_wide   = decay_rate * LEGACY_ADSR_CLK_HZ;
    wire [63:0] release_wide = release_rate * LEGACY_ADSR_CLK_HZ;

    wire [31:0] attack_eff  = LEGACY_RATE_INPUT ? (attack_wide / SAMPLE_CLK_FREQ) : attack_rate;
    wire [31:0] decay_eff   = LEGACY_RATE_INPUT ? (decay_wide / SAMPLE_CLK_FREQ) : decay_rate;
    wire [31:0] release_eff = LEGACY_RATE_INPUT ? (release_wide / SAMPLE_CLK_FREQ) : release_rate;

    wire [31:0] adder_center;
    note_pitch2dds #(.CLK_HZ(CLK_HZ)) transl1(
        .clk(clk),
        .note(note),
        .pitch(pitch),
        .lfo_sig(lfo_sig),
        .lfo_depth(lfo_depth),
        .lfo_depth_fine(lfo_depth_fine),
        .adder(adder_center)
    );

    wire [DDS_WIDTH - 1:0] vco_out;
    dds #(.WIDTH(DDS_WIDTH)) vco(
        .clk(clk),
        .reset(rst),
        .adder(adder_center),
        .signal_out(vco_out)
    );

    wire [DDS_WIDTH - 1:0] saw_phase;
    wire [DDS_WIDTH - 1:0] tri_phase;
    wire [DDS_WIDTH - 1:0] square_phase;
    wire [DDS_WIDTH - 1:0] pwm_phase;
    wire [DDS_WIDTH - 1:0] sin_phase;
    wire [DDS_WIDTH - 1:0] ramp_phase;

    dds2saw    #(.WIDTH(DDS_WIDTH)) u_saw(.signal_in(vco_out), .signal_out(saw_phase));
    dds2tria   #(.WIDTH(DDS_WIDTH)) u_tri(.signal_in(vco_out), .signal_out(tri_phase));
    dds2square #(.WIDTH(DDS_WIDTH)) u_sq(.signal_in(vco_out), .signal_out(square_phase));
    dds2pwm    #(.WIDTH(DDS_WIDTH)) u_pwm(.signal_in(vco_out), .pwm(PWM_DUTY), .signal_out(pwm_phase));
    dds2sin    #(.WIDTH(DDS_WIDTH)) u_sin(.signal_in(vco_out), .signal_out(sin_phase));
    dds2revsaw #(.WIDTH(DDS_WIDTH)) u_rev(.signal_in(vco_out), .signal_out(ramp_phase));

    wire [DDS_WIDTH - 1:0] selected_phase =
        (wave_form == SAW)      ? saw_phase :
        (wave_form == SQUARE)   ? square_phase :
        (wave_form == TRIANGLE) ? tri_phase :
        (wave_form == SINE)     ? sin_phase :
        (wave_form == RAMP)     ? ramp_phase :
        (wave_form == PWM_WAVE) ? pwm_phase :
        {DDS_WIDTH{1'b0}};

    wire signed [15:0] osc_hi =
        $signed(selected_phase[DDS_WIDTH - 1 -: 16]) - 16'sd32768;

    // Bresenham decimator: CLK_Hz -> Fs_audio
    reg [31:0] audio_acc;
    reg        decim_strobe;

    always @(posedge clk) begin
        if (rst) begin
            audio_acc    <= 32'd0;
            decim_strobe <= 1'b0;
        end else begin
            decim_strobe <= 1'b0;
            if (audio_acc + SAMPLE_CLK_FREQ >= CLK_HZ) begin
                audio_acc    <= audio_acc + SAMPLE_CLK_FREQ - CLK_HZ;
                decim_strobe <= 1'b1;
            end else begin
                audio_acc <= audio_acc + SAMPLE_CLK_FREQ;
            end
        end
    end

    assign audio_valid = decim_strobe;

    // VCO boxcar average @ decim_strobe
    reg signed [31:0] vco_sum;
    reg [15:0]        vco_cnt;
    reg signed [15:0] osc_s16;

    always @(posedge clk) begin
        if (rst) begin
            vco_sum <= 32'sd0;
            vco_cnt <= 16'd0;
            osc_s16 <= 16'sd0;
        end else if (decim_strobe) begin
            osc_s16 <= (vco_sum + osc_hi) / $signed({16'd0, vco_cnt + 16'd1});
            vco_sum <= 32'sd0;
            vco_cnt <= 16'd0;
        end else begin
            vco_sum <= vco_sum + osc_hi;
            vco_cnt <= vco_cnt + 16'd1;
        end
    end

    wire [31:0] adsr_env;
    adsr #(
        .ACCUM_BITS(32),
        .RATE_BITS(ADSR_RATE_BITS),
        .CV_BITS(16)
    ) env(
        .clk(clk),
        .rst(rst),
        .tick(decim_strobe),
        .gate(gate),
        .note_on(note_on),
        .attack_rate(attack_eff),
        .decay_rate(decay_eff),
        .sustain_level(sustain_level),
        .release_rate(release_eff),
        .signal_out(adsr_env)
    );

    wire signed [15:0] adsr_cv =
        $signed(($unsigned(adsr_env[31:16]) * 32'd32767) >> 16);

    wire signed [15:0] vca_in_s16;

    generate
        if (USE_SVF) begin : gen_svf
            reg gate_d;
            always @(posedge clk)
                gate_d <= gate;

            wire svf_rst = rst || (gate && !gate_d);

            wire signed [15:0] svf_hp;
            wire signed [15:0] svf_bp;
            wire signed [15:0] svf_lp;
            wire signed [15:0] svf_notch;

            // Scale Q down at high Fc (fixed-point stability @ max resonance).
            localparam [17:0] SVF_Q_F_KNEE = 18'd6500;
            localparam [31:0] SVF_Q_CAP_NUM = 32'd851_961_500; // F_KNEE * 131071
            wire [31:0] svf_q_cap_div = SVF_Q_CAP_NUM / {14'd0, svf_f};
            wire [17:0] svf_q_cap =
                (svf_q_cap_div > 32'd131071) ? 18'd131071 : svf_q_cap_div[17:0];
            wire [17:0] svf_q_eff =
                (svf_f <= SVF_Q_F_KNEE || svf_q <= svf_q_cap) ? svf_q : svf_q_cap;

            svf u_svf(
                .clk(clk),
                .rst(svf_rst),
                .tick(1'b1),
                .f(svf_f),
                .q(svf_q_eff),
                .in(osc_hi),
                .hp(svf_hp),
                .bp(svf_bp),
                .lp(svf_lp),
                .notch(svf_notch)
            );

            wire signed [15:0] svf_sel =
                (svf_mode == 2'd0) ? svf_lp :
                (svf_mode == 2'd1) ? svf_hp :
                (svf_mode == 2'd2) ? svf_bp : svf_notch;

            // Boxcar average SVF output @ decim_strobe (avoid beat/alias at high Q).
            reg signed [31:0] svf_sum;
            reg [15:0]        svf_cnt;
            reg signed [15:0] svf_out_hold;

            always @(posedge clk) begin
                if (rst) begin
                    svf_sum      <= 32'sd0;
                    svf_cnt      <= 16'd0;
                    svf_out_hold <= 16'sd0;
                end else if (decim_strobe) begin
                    svf_out_hold <= (svf_sum + svf_sel) /
                        $signed({16'd0, svf_cnt + 16'd1});
                    svf_sum <= 32'sd0;
                    svf_cnt <= 16'd0;
                end else begin
                    svf_sum <= svf_sum + svf_sel;
                    svf_cnt <= svf_cnt + 16'd1;
                end
            end

            assign vca_in_s16 = svf_out_hold;
        end else begin : gen_no_svf
            assign vca_in_s16 = osc_s16;
        end
    endgenerate

    wire [15:0] vca_out;
    svca16 u_vca(
        .in(vca_in_s16),
        .cv(adsr_cv),
        .signal_out(vca_out)
    );

    generate
        if (OUT_WIDTH == 16) begin : gen_wide
            reg [15:0] signal_out_r;
            always @(posedge clk) begin
                if (rst)
                    signal_out_r <= 16'd32768;
                else if (decim_strobe)
                    signal_out_r <= vca_out;
            end
            assign signal_out = signal_out_r;
        end else begin : gen_narrow
            assign signal_out = vca_out[OUT_WIDTH - 1:0];
        end
    endgenerate

endmodule
