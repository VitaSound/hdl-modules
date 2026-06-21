module mono_voice #(
    parameter CLK_HZ           = 1_000_000,
    parameter OUT_WIDTH        = 16,
    parameter DDS_WIDTH        = 32,
    parameter SAMPLE_CLK_FREQ  = 48000,
    parameter ADSR_CTRL_WIDTH  = 4,
    parameter PWM_DUTY         = 7'd64
)(clk, rst, gate,
  note, pitch, lfo_sig, lfo_depth, lfo_depth_fine, wave_form,
  a, d, s, r,
  signal_out);

    input  wire clk, rst, gate;
    input  wire [6:0] note;
    input  wire [13:0] pitch;
    input  wire [7:0] lfo_sig;
    input  wire [6:0] lfo_depth;
    input  wire [6:0] lfo_depth_fine;
    input  wire [2:0] wave_form;
    input  wire [ADSR_CTRL_WIDTH - 1:0] a, d, s, r;
    output wire [OUT_WIDTH - 1:0] signal_out;

    localparam SAW      = 3'b000;
    localparam SQUARE   = 3'b001;
    localparam TRIANGLE = 3'b010;
    localparam SINE     = 3'b011;
    localparam RAMP     = 3'b100;
    localparam PWM_WAVE = 3'b101;

    localparam integer ADSR_DIV = (CLK_HZ + (SAMPLE_CLK_FREQ / 2)) / SAMPLE_CLK_FREQ;

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

    wire [7:0] osc_u8 = (wave_form == SAW)      ? saw_phase[DDS_WIDTH - 1 -: 8] :
                        (wave_form == SQUARE)   ? square_phase[DDS_WIDTH - 1 -: 8] :
                        (wave_form == TRIANGLE) ? tri_phase[DDS_WIDTH - 1 -: 8] :
                        (wave_form == SINE)     ? sin_phase[DDS_WIDTH - 1 -: 8] :
                        (wave_form == RAMP)     ? ramp_phase[DDS_WIDTH - 1 -: 8] :
                        (wave_form == PWM_WAVE) ? pwm_phase[DDS_WIDTH - 1 -: 8] :
                        8'd128;

    wire adsr_tick;
    frqdivmod #(.DIV(ADSR_DIV)) adsr_div(
        .clk(clk),
        .signal_out(adsr_tick)
    );

    wire adsr_strobe;
    strobe_gen adsr_strobe_gen(
        .clk(clk),
        .f(adsr_tick),
        .signal_out(adsr_strobe)
    );

    wire [23:0] adsr_env;
    adsr #(
        .SAMPLE_CLK_FREQ(SAMPLE_CLK_FREQ),
        .MASTER_CLK_FREQ(CLK_HZ),
        .CTRL_WIDTH(ADSR_CTRL_WIDTH)
    ) env(
        .clk(clk),
        .rst(rst),
        .low_strobe(adsr_strobe),
        .gate(gate),
        .a(a),
        .d(d),
        .s(s),
        .r(r),
        .signal_out(adsr_env)
    );

    wire [7:0] adsr_cv = adsr_env[23:16];

    generate
        if (OUT_WIDTH == 16) begin : gen_wide
            wire [15:0] vca_out;
            svca_wide u_vca(
                .in(osc_u8),
                .cv(adsr_cv),
                .signal_out(vca_out)
            );
            assign signal_out = vca_out;
        end else begin : gen_narrow
            wire [7:0] vca_out;
            svca u_vca(
                .in(osc_u8),
                .cv(adsr_cv),
                .signal_out(vca_out)
            );
            assign signal_out = vca_out;
        end
    endgenerate
endmodule
