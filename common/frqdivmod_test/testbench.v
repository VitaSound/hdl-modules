`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;
  localparam integer DIV21 = 21;
  localparam integer K = 100;
  localparam integer WINDOW = DIV21 * K;

  wire signal_out_2;
  wire signal_out_3;
  wire signal_out_4;
  wire signal_out_21;
  wire signal_out_21_1m;
  wire strobe_21;
  wire strobe_21_1m;
  wire [15:0] div_out_5_20;

  reg clk50M;
  reg clk1M;

  integer i;
  integer rises;
  integer strobes;
  reg prev_out;
  reg prev_strobe;

  initial clk50M <= 0;
  initial clk1M <= 0;
  always #10 clk50M <= ~clk50M;
  always #500 clk1M <= ~clk1M;

  frqdivmod #(.DIV(2)) frqdivmod_2(
    .clk(clk50M),
    .signal_out(signal_out_2)
  );

  frqdivmod #(.DIV(3)) frqdivmod_3(
    .clk(clk50M),
    .signal_out(signal_out_3)
  );

  frqdivmod #(.DIV(4)) frqdivmod_4(
    .clk(clk50M),
    .signal_out(signal_out_4)
  );

  frqdivmod #(.DIV(DIV21)) frqdivmod_21(
    .clk(clk50M),
    .signal_out(signal_out_21)
  );

  frqdivmod #(.DIV(DIV21)) frqdivmod_21_1m(
    .clk(clk1M),
    .signal_out(signal_out_21_1m)
  );

  strobe_gen strobe_gen_21(
    .clk(clk50M),
    .f(signal_out_21),
    .signal_out(strobe_21)
  );

  strobe_gen strobe_gen_21_1m(
    .clk(clk1M),
    .f(signal_out_21_1m),
    .signal_out(strobe_21_1m)
  );

  genvar g;
  generate
    for (g = 5; g <= 20; g = g + 1) begin : gen_div_5_20
      frqdivmod #(.DIV(g)) u_div(
        .clk(clk1M),
        .signal_out(div_out_5_20[g - 5])
      );
    end
  endgenerate

  task check_div_rises;
    input integer div;
    input integer out_idx;
    input integer k;
    integer window;
    integer n;
    integer rise_count;
    reg prev;
    begin
      window = div * k;
      rise_count = 0;
      prev = div_out_5_20[out_idx];
      for (n = 0; n < window; n = n + 1) begin
        @(posedge clk1M);
        if (div_out_5_20[out_idx] === 1'bx) begin
          $display("FAIL frqdivmod DIV=%0d: signal_out is X at n=%0d", div, n);
          $fatal(1, "frqdivmod DIV sweep");
        end
        if (div_out_5_20[out_idx] && !prev)
          rise_count = rise_count + 1;
        prev = div_out_5_20[out_idx];
      end
      if (rise_count < (k - 1) || rise_count > (k + 1)) begin
        $display("FAIL frqdivmod DIV=%0d: rises=%0d expect ~%0d over %0d clks",
                 div, rise_count, k, window);
        $fatal(1, "frqdivmod DIV sweep");
      end
      $display("OK frqdivmod DIV=%0d: rises=%0d / %0d clks", div, rise_count, window);
    end
  endtask

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);

    repeat (4) @(posedge clk50M);

    rises = 0;
    prev_out = signal_out_21;
    for (i = 0; i < WINDOW; i = i + 1) begin
      @(posedge clk50M);
      if (signal_out_21 === 1'bx) begin
        $display("FAIL frqdivmod DIV=21: signal_out is X at t=%0d i=%0d", $time, i);
        $fatal(1, "frqdivmod odd DIV regression");
      end
      if (signal_out_21 && !prev_out)
        rises = rises + 1;
      prev_out = signal_out_21;
    end

    if (rises < (K - 1) || rises > (K + 1)) begin
      $display("FAIL frqdivmod DIV=21: rises=%0d expect ~%0d over %0d clks",
               rises, K, WINDOW);
      $fatal(1, "frqdivmod odd DIV regression");
    end

    strobes = 0;
    prev_strobe = strobe_21;
    for (i = 0; i < WINDOW; i = i + 1) begin
      @(posedge clk50M);
      if (strobe_21 && !prev_strobe)
        strobes = strobes + 1;
      prev_strobe = strobe_21;
    end

    if (strobes < (K - 1) || strobes > (K + 1)) begin
      $display("FAIL frqdivmod+strobe DIV=21: strobes=%0d expect ~%0d", strobes, K);
      $fatal(1, "frqdivmod strobe chain regression");
    end

    repeat (4) @(posedge clk1M);
    for (i = 0; i < WINDOW; i = i + 1) begin
      @(posedge clk1M);
      if (signal_out_21_1m === 1'bx) begin
        $display("FAIL frqdivmod DIV=21 @1MHz: X at i=%0d", i);
        $fatal(1, "frqdivmod 1MHz regression");
      end
      if (strobe_21_1m === 1'bx) begin
        $display("FAIL strobe DIV=21 @1MHz: X at i=%0d", i);
        $fatal(1, "frqdivmod 1MHz regression");
      end
    end

    repeat (4) @(posedge clk1M);
    for (i = 5; i <= 20; i = i + 1)
      check_div_rises(i, i - 5, 50);

    $display("frqdivmod self-check: OK (DIV=21, rises=%0d, strobes=%0d)", rises, strobes);

    #TEST_DURATION;
    $display("test completed.");
    $finish;
  end
endmodule
