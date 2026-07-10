`timescale 1ns / 1ps

module svf_voice_isolated_tb();
    localparam CLK_HZ = 1_000_000;
    localparam integer NOTE = 60;

    reg clk = 0;
    reg rst = 1;
    reg gate = 0;
    reg note_on = 0;
    reg [2:0] wave_form = 3'd3;  // sine
    reg [6:0] note = NOTE;
    reg [13:0] pitch = 14'd8192;
    reg [7:0] lfo_sig = 8'd128;
    reg [6:0] lfo_depth = 7'd0;
    reg [6:0] lfo_depth_fine = 7'd0;
    reg [31:0] attack_rate = 32'd7540;
    reg [31:0] decay_rate = 32'd7540;
    reg [31:0] sustain_level = {7'd127, 25'b0};
    reg [31:0] release_rate = 32'd7540;
    reg [17:0] svf_f = 18'd27086;
    reg [17:0] svf_q = 18'd8192;
    reg [1:0]  svf_mode = 2'd0;

    wire [15:0] signal_out;

    mono_voice #(
        .CLK_HZ(CLK_HZ),
        .OUT_WIDTH(16),
        .SAMPLE_CLK_FREQ(44100),
        .LEGACY_RATE_INPUT(1),
        .USE_SVF(1)
    ) dut(
        .clk(clk),
        .rst(rst),
        .gate(gate),
        .note_on(note_on),
        .sound_off(1'b0),
        .note(note),
        .pitch(pitch),
        .lfo_sig(lfo_sig),
        .lfo_depth(lfo_depth),
        .lfo_depth_fine(lfo_depth_fine),
        .wave_form(wave_form),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .svf_f(svf_f),
        .svf_q(svf_q),
        .svf_mode(svf_mode),
        .signal_out(signal_out)
    );

    integer fd;
    integer sample_count;
    integer prev_out;
    integer big_jumps;
    integer i;

    always #(500) clk = ~clk;

    initial begin
        fd = $fopen("svf_voice_samples.txt", "w");
        sample_count = 0;
        big_jumps = 0;
        prev_out = 32768;

        repeat (20) @(posedge clk);
        rst <= 0;
        repeat (100) @(posedge clk);
        gate <= 1;

        for (i = 0; i < 500000; i = i + 1) begin
            @(posedge clk);
            if (sample_count >= 44100)
                i = 500000;
            if (dut.decim_strobe) begin
                $fwrite(fd, "%0d\n", signal_out);
                if ((signal_out > prev_out ? signal_out - prev_out : prev_out - signal_out) > 16'd12000)
                    big_jumps = big_jumps + 1;
                prev_out = signal_out;
                sample_count = sample_count + 1;
            end
        end

        $fclose(fd);
        $display("samples=%0d big_jumps=%0d", sample_count, big_jumps);
        if (big_jumps > sample_count / 4)
            $display("FAIL: unstable SVF output");
        else
            $display("OK: stable SVF output");
        $finish;
    end
endmodule
