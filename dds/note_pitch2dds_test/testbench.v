`timescale 1ns / 1ps

module testbench();
  localparam CLK_HZ = 1_000_000;
  localparam TEST_DURATION = 10000000;

  reg clk;
  reg [6:0] note;
  reg [13:0] pitch;
  reg [7:0] lfo_sig;
  reg [6:0] lfo_depth;
  reg [6:0] lfo_depth_fine;
  wire [31:0] adder;

  integer errors;

  always #500 clk <= ~clk;

  note_pitch2dds #(.CLK_HZ(CLK_HZ)) dut(
    .clk(clk),
    .note(note),
    .pitch(pitch),
    .lfo_sig(lfo_sig),
    .lfo_depth(lfo_depth),
    .lfo_depth_fine(lfo_depth_fine),
    .adder(adder)
  );

  function [31:0] expected_adder;
    input [8:0] midi_note;
    real hz;
    begin
      hz = 440.0 * $pow(2.0, (midi_note - 69.0) / 12.0);
      expected_adder = $rtoi(4294967296.0 * hz / CLK_HZ);
    end
  endfunction

  function [31:0] expected_interp;
    input [8:0] note_int;
    input [7:0] note_frac;
    reg [31:0] a0;
    reg [31:0] a1;
    begin
      a0 = expected_adder(note_int);
      a1 = expected_adder(note_int + 9'd1);
      expected_interp = (a0 * (9'd255 - {1'b0, note_frac}) + a1 * {1'b0, note_frac}) >> 8;
    end
  endfunction

  initial begin
    clk = 0;
    note = 7'd69;
    pitch = 14'd8192;
    lfo_sig = 8'd128;
    lfo_depth = 7'd0;
    lfo_depth_fine = 7'd0;
    errors = 0;

    repeat (4) @(posedge clk);
    repeat (4) @(posedge clk);
    if (adder !== expected_interp(9'd69, 8'd0)) begin
      $display("FAIL pitch center: got=%0d expect=%0d", adder, expected_interp(9'd69, 8'd0));
      errors = errors + 1;
    end

    pitch = 14'd16383;
    repeat (8) @(posedge clk);
    if (adder <= expected_interp(9'd69, 8'd0)) begin
      $display("FAIL pitch max bend: adder=%0d not above center", adder);
      errors = errors + 1;
    end

    pitch = 14'd8192;
    lfo_depth = 7'd64;
    lfo_sig = 8'd192;
    repeat (8) @(posedge clk);
    if (adder === expected_interp(9'd69, 8'd0)) begin
      $display("FAIL LFO pitch: adder unchanged at center");
      errors = errors + 1;
    end

    if (errors)
      $fatal(1, "note_pitch2dds: %0d check(s) failed", errors);
    else
      $display("note_pitch2dds self-check: OK");
  end

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);
    #TEST_DURATION;
    $display("note_pitch2dds test completed.");
    $finish;
  end
endmodule
