`timescale 1ns / 1ps

module testbench();
    localparam CLK_HZ        = 1_000_000;
    localparam CLK_PERIOD_NS = 1_000_000_000 / CLK_HZ;
    localparam FC_HZ         = 5000.0;
    localparam Q_VAL         = 2.0;
    localparam NOISE_SAMPLES = 65536;
    localparam IMPULSE_LEN   = 4096;
    localparam WARMUP        = 4096;

    reg clk;
    reg rst;
    reg tick;
    reg signed [15:0] noise_in;
    wire [7:0] rnd8_out;

    reg signed [17:0] f_coeff;
    reg signed [17:0] q_coeff;
    wire signed [15:0] hp, bp, lp, notch;

  integer errors;
  integer n;
  integer sample_idx;
  integer abs_in;
  integer abs_lp;
  integer abs_val;
  real sum_in_sq;
  real sum_lp_sq;
  integer peak_bp;
  integer peak_late;

    function [17:0] svf_f_coeff;
        input real fc_hz;
        input real fs_hz;
        real fv;
        begin
            fv = 2.0 * $sin(3.141592653589793 * fc_hz / fs_hz);
            svf_f_coeff = $rtoi(fv * 131072.0);
        end
    endfunction

    function [17:0] svf_q_coeff;
        input real Q;
        real qv;
        begin
            qv = 1.0 / Q;
            svf_q_coeff = $rtoi(qv * 131072.0);
        end
    endfunction

    always #(CLK_PERIOD_NS / 2) clk <= ~clk;

    rnd8 rnd_src(
        .clk(clk),
        .signal_out(rnd8_out)
    );

    svf dut(
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .f(f_coeff),
        .q(q_coeff),
        .in(noise_in),
        .hp(hp),
        .bp(bp),
        .lp(lp),
        .notch(notch)
    );

    task run_ticks;
        input integer count;
        integer k;
        begin
            for (k = 0; k < count; k = k + 1) begin
                @(posedge clk);
                tick <= 1'b1;
                @(posedge clk);
                tick <= 1'b0;
            end
        end
    endtask

    initial begin
        clk       = 1'b0;
        rst       = 1'b1;
        tick      = 1'b0;
        noise_in  = 16'sd0;
        errors    = 0;
        f_coeff   = svf_f_coeff(FC_HZ, CLK_HZ);
        q_coeff   = svf_q_coeff(Q_VAL);

        $dumpfile("out.vcd");
        $dumpvars(0, testbench);

        #(CLK_PERIOD_NS * 4);
        rst <= 1'b0;

        // --- Impulse response (Katjaas): high Q for visible ringing ---
        rst <= 1'b1;
        #(CLK_PERIOD_NS * 2);
        rst <= 1'b0;

        f_coeff <= svf_f_coeff(FC_HZ, CLK_HZ);
        q_coeff <= svf_q_coeff(8.0);

        noise_in <= 16'sd32767;
        @(posedge clk);
        tick <= 1'b1;
        @(posedge clk);
        tick <= 1'b0;
        noise_in <= 16'sd0;

        peak_bp   = 0;
        peak_late = 0;
        for (n = 0; n < IMPULSE_LEN; n = n + 1) begin
            @(posedge clk);
            tick <= 1'b1;
            @(posedge clk);
            tick <= 1'b0;
            abs_val = bp;
            if (abs_val < 0) abs_val = -abs_val;
            if (n < 256 && abs_val > peak_bp)
                peak_bp = abs_val;
            if (n > 1024 && abs_val > peak_late)
                peak_late = abs_val;
        end

        if (peak_bp < 512) begin
            $display("FAIL svf impulse: peak_bp=%0d too small", peak_bp);
            errors = errors + 1;
        end else if (peak_late > (peak_bp / 3)) begin
            $display("FAIL svf impulse: no decay peak_late=%0d peak_bp=%0d",
                     peak_late, peak_bp);
            errors = errors + 1;
        end else begin
            $display("PASS svf impulse: peak_bp=%0d peak_late=%0d",
                     peak_bp, peak_late);
        end

        // --- White noise segment for FFT (last NOISE_SAMPLES in VCD) ---
        rst <= 1'b1;
        #(CLK_PERIOD_NS * 2);
        rst <= 1'b0;

        f_coeff <= svf_f_coeff(FC_HZ, CLK_HZ);
        q_coeff <= svf_q_coeff(Q_VAL);

        run_ticks(WARMUP);

        sum_in_sq = 0;
        sum_lp_sq = 0;
        for (sample_idx = 0; sample_idx < NOISE_SAMPLES; sample_idx = sample_idx + 1) begin
            noise_in <= ($signed({1'b0, rnd8_out}) - 9'sd128) <<< 8;
            @(posedge clk);
            tick <= 1'b1;
            @(posedge clk);
            tick <= 1'b0;

            abs_in = noise_in;
            if (abs_in < 0) abs_in = -abs_in;
            abs_lp = lp;
            if (abs_lp < 0) abs_lp = -abs_lp;
            sum_in_sq = sum_in_sq + $itor(abs_in * abs_in);
            sum_lp_sq = sum_lp_sq + $itor(abs_lp * abs_lp);
        end

        if (sum_lp_sq >= sum_in_sq) begin
            $display("FAIL svf noise RMS: lp_sq=%0d in_sq=%0d", sum_lp_sq, sum_in_sq);
            errors = errors + 1;
        end else begin
            $display("PASS svf noise RMS: lp_sq=%0d in_sq=%0d", sum_lp_sq, sum_in_sq);
        end

        if (errors != 0) begin
            $display("self-check: %0d error(s)", errors);
            $fatal(1, "svf self-check failed");
        end

        $display("self-check: OK");
        $finish;
    end
endmodule
