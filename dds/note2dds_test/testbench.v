`timescale 1ns / 1ps

module testbench();
  localparam CLK_HZ = 1_000_000;
  localparam TEST_DURATION = 5000000;

  reg clk;
  reg [8:0] note;
  wire [31:0] adder;

  integer errors;
  integer n;
  reg [31:0] prev_adder;

  always #500 clk <= ~clk;

  note2dds #(.CLK_HZ(CLK_HZ)) dut(
    .clk(clk),
    .note(note),
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

  initial begin
    clk = 0;
    note = 0;
    errors = 0;

    repeat (4) @(posedge clk);

    note = 9'd69;
    @(posedge clk);
    @(posedge clk);
    if (adder !== expected_adder(69)) begin
      $display("FAIL note2dds A4: got=%0d expect=%0d", adder, expected_adder(69));
      errors = errors + 1;
    end

    note = 9'd60;
    @(posedge clk);
    @(posedge clk);
    prev_adder = adder;
    for (n = 61; n <= 72; n = n + 1) begin
      note = n[8:0];
      @(posedge clk);
      @(posedge clk);
      if (adder <= prev_adder) begin
        $display("FAIL note2dds monotonic: note=%0d adder=%0d prev=%0d", n, adder, prev_adder);
        errors = errors + 1;
      end
      prev_adder = adder;
    end

    if (errors)
      $fatal(1, "note2dds: %0d check(s) failed", errors);
    else
      $display("note2dds self-check: OK");
  end

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);
    #TEST_DURATION;
    $display("note2dds test completed.");
    $finish;
  end
endmodule
