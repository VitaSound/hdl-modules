`timescale 1ns / 1ps

module testbench();
  localparam CLK_HZ = 1_000_000;
  localparam TEST_DURATION = 200_000_000;
  localparam integer EXP_PERIOD_NS = 1_000_000_000 / 440;
  localparam integer TOL_NS = EXP_PERIOD_NS / 20;

  reg clk;
  reg rst;
  reg gate;
  reg [6:0] note;
  reg [13:0] pitch;
  reg [7:0] lfo_sig;
  reg [6:0] lfo_depth;
  reg [6:0] lfo_depth_fine;
  reg [2:0] wave_form;
  reg [3:0] a;
  reg [3:0] d;
  reg [3:0] s;
  reg [3:0] r;
  wire [15:0] signal_out;

  integer errors;
  integer wf;
  integer measured_ns;
  integer ok;
  reg prev_hi;
  reg prev_cross;
  integer t_edges [0:2];
  integer edge_count;
  integer i;
  integer t_limit;

  always #500 clk <= ~clk;

  mono_voice #(
    .CLK_HZ(CLK_HZ),
    .OUT_WIDTH(16),
    .SAMPLE_CLK_FREQ(48000)
  ) dut(
    .clk(clk),
    .rst(rst),
    .gate(gate),
    .note(note),
    .pitch(pitch),
    .lfo_sig(lfo_sig),
    .lfo_depth(lfo_depth),
    .lfo_depth_fine(lfo_depth_fine),
    .wave_form(wave_form),
    .a(a),
    .d(d),
    .s(s),
    .r(r),
    .signal_out(signal_out)
  );

  task measure_period;
    input [2:0] wf_in;
    output integer period_out;
    output integer pass;
    begin
      wave_form = wf_in;
      edge_count = 0;
      pass = 1;
      period_out = 0;
      prev_cross = (signal_out >= 16'd32768);

      repeat (5000) @(posedge clk);

      t_limit = $time + 12_000_000;

      while (edge_count < 3 && $time < t_limit) begin
        @(posedge clk);
        if ((signal_out >= 16'd32768) && !prev_cross) begin
          t_edges[edge_count] = $time;
          edge_count = edge_count + 1;
        end
        prev_cross = (signal_out >= 16'd32768);
      end

      if (edge_count < 3) begin
        $display("FAIL mono_voice wf=%0d: only %0d edges", wf_in, edge_count);
        pass = 0;
      end else begin
        period_out = t_edges[2] - t_edges[1];
        if (period_out < (EXP_PERIOD_NS - TOL_NS) || period_out > (EXP_PERIOD_NS + TOL_NS)) begin
          $display("FAIL mono_voice wf=%0d: period=%0d ns expect=%0d +/-%0d",
                   wf_in, period_out, EXP_PERIOD_NS, TOL_NS);
          pass = 0;
        end else begin
          $display("OK mono_voice wf=%0d: period=%0d ns", wf_in, period_out);
        end
      end
    end
  endtask

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);

    clk = 0;
    rst = 1;
    gate = 0;
    note = 7'd69;
    pitch = 14'd8192;
    lfo_sig = 8'd128;
    lfo_depth = 7'd0;
    lfo_depth_fine = 7'd0;
    wave_form = 3'd1;
    a = 4'd0;
    d = 4'd0;
    s = 4'd15;
    r = 4'd15;
    errors = 0;

    repeat (4) @(posedge clk);
    rst = 0;
    gate = 1;
    repeat (15000) @(posedge clk);

    for (wf = 0; wf <= 5; wf = wf + 1) begin
      measure_period(wf[2:0], measured_ns, ok);
      if (!ok)
        errors = errors + 1;
    end

    r = 4'd0;
    gate = 0;
    repeat (200000) @(posedge clk);
    if ((signal_out > 16'd33000) || (signal_out < 16'd32500)) begin
      $display("FAIL mono_voice release: signal_out=%0d expect ~32768", signal_out);
      errors = errors + 1;
    end

    if (errors)
      $fatal(1, "mono_voice: %0d check(s) failed", errors);
    else
      $display("mono_voice self-check: OK (A4 440 Hz all waveforms)");

    #10000;
    $display("mono_voice test completed.");
    $finish;
  end
endmodule
