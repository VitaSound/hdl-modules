`timescale 1ns / 1ps

module testbench();

    localparam CLK_HZ = 1_000_000;
    localparam integer CLK_PERIOD_NS = 1000;

    reg clk;
    reg rst;
    reg [6:0] rate7;
    wire [7:0] sig_out;

    integer errors;
    integer i;
    integer t_prev;
    integer t_cross;
    integer crossings;
    reg prev_below;

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    lfo #(
        .CLK_HZ(CLK_HZ)
    ) dut(
        .clk(clk),
        .rst(rst),
        .rate7(rate7),
        .shape(3'd0),
        .sig_out(sig_out)
    );

    task check_lfo_period;
        input [6:0] rate_in;
        input integer expect_period_us;
        input integer tol_pct;
        integer period_us;
        integer lo_us;
        integer hi_us;
        begin
            rate7 = rate_in;
            rst = 1;
            repeat (8) @(posedge clk);
            rst = 0;

            crossings = 0;
            t_prev = 0;
            prev_below = 1'b1;

            lo_us = expect_period_us * (100 - tol_pct) / 100;
            hi_us = expect_period_us * (100 + tol_pct) / 100;

            for (i = 0; i < 5_000_000; i = i + 1) begin
                @(posedge clk);
                if (sig_out >= 8'd128) begin
                    if (prev_below) begin
                        if (crossings > 0) begin
                            period_us = ($time - t_prev) / 1000;
                            if (crossings == 2) begin
                                if (period_us < lo_us || period_us > hi_us) begin
                                    $display("FAIL lfo rate=%0d: period=%0d us expect %0d us +/-%0d%%",
                                             rate_in, period_us, expect_period_us, tol_pct);
                                    errors = errors + 1;
                                end else begin
                                    $display("OK lfo rate=%0d: period=%0d us",
                                             rate_in, period_us);
                                end
                                disable check_lfo_period;
                            end
                        end
                        t_prev = $time;
                        crossings = crossings + 1;
                    end
                    prev_below = 1'b0;
                end else begin
                    prev_below = 1'b1;
                end
            end
            $display("FAIL lfo rate=%0d: not enough crossings", rate_in);
            errors = errors + 1;
        end
    endtask

    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, testbench);

        errors = 0;
        clk = 0;
        rst = 1;
        rate7 = 7'd0;

        // rate7=64 → ~1.771 Hz → period ~564 ms
        check_lfo_period(7'd64, 564000, 15);

        // rate7=127 → 30 Hz → period ~33.3 ms
        check_lfo_period(7'd127, 33330, 15);

        if (errors)
            $fatal(1, "lfo: %0d check(s) failed", errors);

        $display("lfo self-check: OK");
        $finish;
    end

endmodule
