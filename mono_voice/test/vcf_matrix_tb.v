`timescale 1ns / 1ps

// VCF matrix: 20 log Fc x 4 modes x 5 Q — sine excitation, peak check.
module vcf_matrix_tb();

    localparam CLK_HZ = 1_000_000;
    localparam FS_HZ  = 44100;
    localparam integer FC_N = 20;
    localparam integer Q_N  = 5;
    localparam integer WARMUP = 2048;
    localparam integer MEAS   = 4096;

    localparam real FC_MIN = 10.0;
    localparam real FC_MAX = 20000.0;
    localparam real FC_RATIO = 2000.0;
    localparam real LN2 = 0.6931471805599453;

    reg clk;
    reg rst;
    reg gate;
    reg note_on;
    reg [6:0] note;
    reg [13:0] pitch;
    reg [2:0] wave_form;
    reg [31:0] attack_rate;
    reg [31:0] decay_rate;
    reg [31:0] sustain_level;
    reg [31:0] release_rate;
    reg [17:0] svf_f;
    reg [17:0] svf_q;
    reg [1:0]  svf_mode;

    wire [15:0] signal_out;
    wire        audio_valid;

    integer errors;
    integer k, mode, qi;
    integer q_cc [0:4];
    integer sample_count;
    integer abs_dev;
    integer peak;
    real fc_hz;
    real f_in;
    real f_stop;

    initial q_cc[0] = 0;
    initial q_cc[1] = 31;
    initial q_cc[2] = 63;
    initial q_cc[3] = 95;
    initial q_cc[4] = 127;

    always #500 clk <= ~clk;

    mono_voice #(
        .CLK_HZ(CLK_HZ),
        .OUT_WIDTH(16),
        .SAMPLE_CLK_FREQ(FS_HZ),
        .LEGACY_RATE_INPUT(0),
        .USE_SVF(1)
    ) dut(
        .clk(clk),
        .rst(rst),
        .gate(gate),
        .note_on(note_on),
        .sound_off(1'b0),
        .note(note),
        .pitch(pitch),
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
        .audio_valid(audio_valid),
        .signal_out(signal_out)
    );

    function [17:0] f_coeff;
        input real fc;
        input real fs;
        real fv;
        begin
            fv = 2.0 * $sin(3.141592653589793 * fc / fs);
            f_coeff = $rtoi(fv * 131072.0);
        end
    endfunction

    function [17:0] q_coeff_cc;
        input integer cc;
        real q;
        real qv;
        begin
            q = 16.0 * $pow(0.5 / 16.0, cc / 127.0);
            qv = 1.0 / q;
            q_coeff_cc = $rtoi(qv * 131072.0);
        end
    endfunction

    function integer note_for_hz;
        input real hz;
        real n;
        begin
            if (hz <= 0.0)
                note_for_hz = 0;
            else begin
                n = 69.0 + 12.0 * ($ln(hz / 440.0) / LN2);
                if (n < 0.0)
                    note_for_hz = 0;
                else if (n > 127.0)
                    note_for_hz = 127;
                else
                    note_for_hz = $rtoi(n);
            end
        end
    endfunction

    task measure_peak;
        output integer peak_out;
        integer n;
        integer d;
        begin
            peak_out = 0;
            repeat (WARMUP) begin
                @(posedge clk);
                if (audio_valid) begin
                    #0;
                    d = (signal_out >= 16'd32768)
                        ? (signal_out - 16'd32768)
                        : (16'd32768 - signal_out);
                    if (d > peak_out)
                        peak_out = d;
                end
            end
            for (n = 0; n < MEAS; n = n + 1) begin
                @(posedge clk);
                if (audio_valid) begin
                    #0;
                    d = (signal_out >= 16'd32768)
                        ? (signal_out - 16'd32768)
                        : (16'd32768 - signal_out);
                    if (d > peak_out)
                        peak_out = d;
                end
            end
        end
    endtask

    task run_tone;
        input real f_hz;
        output integer peak_out;
        begin
            note = note_for_hz(f_hz);
            rst = 1;
            repeat (8) @(posedge clk);
            rst = 0;
            repeat (10000) @(posedge clk);
            measure_peak(peak_out);
        end
    endtask

    task check_case;
        input integer k_in;
        input integer mode_in;
        input integer q_in;
        integer p_pass;
        integer p_stop;
        begin
            fc_hz = FC_MIN * $pow(FC_RATIO, k_in / (FC_N - 1.0));
            svf_f = f_coeff(fc_hz, CLK_HZ);
            svf_q = q_coeff_cc(q_in);
            svf_mode = mode_in[1:0];
            wave_form = 3'd3;
            attack_rate  = 32'hFFFF_FFFF;
            decay_rate   = 32'd1;
            sustain_level = {32{1'b1}};
            release_rate = 32'd1;
            gate = 1;
            note_on = 0;
            pitch = 14'd8192;

            case (mode_in)
                0: begin
                    f_in   = fc_hz / 4.0;
                    f_stop = fc_hz * 4.0;
                end
                1: begin
                    f_in   = fc_hz * 4.0;
                    f_stop = fc_hz / 4.0;
                end
                default: begin
                    f_in   = fc_hz;
                    f_stop = fc_hz * 4.0;
                end
            endcase

            run_tone(f_in, p_pass);
            run_tone(f_stop, p_stop);

            if (p_pass < 1000) begin
                $display("FAIL vcf k=%0d mode=%0d q=%0d fc=%0.0f silent pass=%0d",
                         k_in, mode_in, q_in, fc_hz, p_pass);
                errors = errors + 1;
            end else if ((mode_in == 0 || mode_in == 1) && fc_hz <= 6000.0 && q_in < 127
                         && (p_pass <= p_stop)) begin
                $display("FAIL vcf k=%0d mode=%0d q=%0d fc=%0.0f pass=%0d stop=%0d",
                         k_in, mode_in, q_in, fc_hz, p_pass, p_stop);
                errors = errors + 1;
            end else if (mode_in == 2 && p_pass < 500) begin
                $display("FAIL vcf k=%0d mode=%0d q=%0d fc=%0.0f bp pass=%0d",
                         k_in, mode_in, q_in, fc_hz, p_pass);
                errors = errors + 1;
            end else if (mode_in == 3 && p_pass < 300) begin
                $display("FAIL vcf k=%0d mode=%0d q=%0d fc=%0.0f notch pass=%0d",
                         k_in, mode_in, q_in, fc_hz, p_pass);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        clk = 0;
        rst = 1;
        gate = 0;
        note_on = 0;

        for (k = 0; k < FC_N; k = k + 1) begin
            for (mode = 0; mode < 4; mode = mode + 1) begin
                for (qi = 0; qi < Q_N; qi = qi + 1) begin
                    case (mode)
                        0: check_case(k, mode, q_cc[qi]);
                        1: check_case(k, mode, q_cc[qi]);
                        2: check_case(k, mode, q_cc[qi]);
                        3: check_case(k, mode, q_cc[qi]);
                    endcase
                end
            end
        end

        if (errors)
            $fatal(1, "vcf_matrix: %0d case(s) failed", errors);

        $display("vcf_matrix self-check: OK (20x4x5)");
        $finish;
    end
endmodule
