`timescale 1ns / 1ps

module testbench();
    parameter TEST_DURATION = 5_000_000;

    reg clk;
    reg rst;
    reg tick;
    reg gate;
    reg [31:0] attack_rate;
    reg [31:0] decay_rate;
    reg [31:0] sustain_level;
    reg [31:0] release_rate;

    wire [31:0] signal_out;

    initial clk <= 0;
    always #10 clk <= ~clk;

    adsr env(
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .gate(gate),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .signal_out(signal_out)
    );

    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, testbench);

        rst = 1;
        tick = 0;
        gate = 0;
        attack_rate = 32'd10000;
        decay_rate = 32'd10000;
        sustain_level = {7'd64, 25'b0};
        release_rate = 32'd8000;

        repeat (4) @(posedge clk);
        rst = 0;

        repeat (100) begin
            @(posedge clk);
            tick <= 1'b1;
            @(posedge clk);
            tick <= 1'b0;
        end

        gate = 1;
        repeat (5000) begin
            @(posedge clk);
            tick <= 1'b1;
            @(posedge clk);
            tick <= 1'b0;
        end

        if (signal_out == 32'd0) begin
            $display("FAIL adsr: signal still zero after gate on");
            $finish(1);
        end

        gate = 0;
        repeat (20000) begin
            @(posedge clk);
            tick <= 1'b1;
            @(posedge clk);
            tick <= 1'b0;
        end

        if (signal_out != 32'd0) begin
            $display("FAIL adsr: signal not zero after release, got=%0d", signal_out);
            $finish(1);
        end

        $display("OK adsr_test");
        #TEST_DURATION;
        $display("adsr test completed.");
        $finish;
    end
endmodule
