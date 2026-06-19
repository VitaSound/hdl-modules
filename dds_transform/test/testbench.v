`timescale 1us / 1ns

module testbench();
  parameter WIDTH = 32;
  parameter TEST_DURATION = 1000000;
  reg [WIDTH-1:0] adder_input;
  wire [WIDTH-1:0] signal_out;
  wire [WIDTH-1:0] tria_signal_out;
  wire [WIDTH-1:0] saw_signal_out;
  wire [WIDTH-1:0] revsaw_signal_out;
  wire [WIDTH-1:0] square_signal_out;
  wire [WIDTH-1:0] pwm_signal_out;
  wire [WIDTH-1:0] sin_signal_out;

  reg clk;
  reg reset;

  integer errors;
  reg [31:0] phase_in32;
  wire [31:0] sin_out32;
  reg [15:0] phase_in16;
  wire [15:0] sin_out16;

  localparam [31:0] MID32 = 32'h7fffffff;
  localparam [15:0] MID16 = 16'h7fff;

  always
    #10 clk <= ~clk;

  initial
  begin
    reset = 1;
    clk <= 0;
    adder_input <= 33333333;
    #50;
    reset = 0;
  end

  dds #(WIDTH) dds1_1(
    .clk(clk),
    .reset(reset),
    .adder(adder_input),
    .signal_out(signal_out)
  );

  dds2tria #(WIDTH) dds2tria_1(
    .signal_in(signal_out),
    .signal_out(tria_signal_out)
  );

  dds2saw #(WIDTH) dds2saw_1(
    .signal_in(signal_out),
    .signal_out(saw_signal_out)
  );

  dds2revsaw #(WIDTH) dds2revsaw_1(
    .signal_in(signal_out),
    .signal_out(revsaw_signal_out)
  );

  dds2square #(WIDTH) dds2square_1(
    .signal_in(signal_out),
    .signal_out(square_signal_out)
  );

  dds2pwm #(WIDTH) dds2pwm_1(
    .signal_in(signal_out),
    .pwm(7'd32),
    .signal_out(pwm_signal_out)
  );

  dds2sin #(WIDTH) dds2sin_1(
    .signal_in(signal_out),
    .signal_out(sin_signal_out)
  );

  dds2sin #(.WIDTH(32), .LUT_BITS(3)) dut_sin32(
    .signal_in(phase_in32),
    .signal_out(sin_out32)
  );

  dds2sin #(.WIDTH(16), .LUT_BITS(3)) dut_sin16(
    .signal_in(phase_in16),
    .signal_out(sin_out16)
  );

  task check_sin32;
    input [31:0] phase;
    input [31:0] expect;
    input [256*8-1:0] label;
    begin
      phase_in32 = phase;
      #1;
      if (sin_out32 !== expect) begin
        $display("FAIL %0s: phase=%h got=%h expect=%h", label, phase, sin_out32, expect);
        errors = errors + 1;
      end
    end
  endtask

  task check_sin16;
    input [15:0] phase;
    input [15:0] expect;
    input [256*8-1:0] label;
    begin
      phase_in16 = phase;
      #1;
      if (sin_out16 !== expect) begin
        $display("FAIL %0s: phase=%h got=%h expect=%h", label, phase, sin_out16, expect);
        errors = errors + 1;
      end
    end
  endtask

  initial
  begin
    errors = 0;
    phase_in32 = 0;
    phase_in16 = 0;

    check_sin32({2'b00, 3'b000, 27'b0}, MID32, "sin32(0)");
    check_sin32({2'b00, 3'b111, 27'b0}, 32'hfffffffe, "sin32(+max)");
    check_sin32({2'b01, 3'b000, 27'b0}, 32'hfffffffe, "sin32(mirror)");
    check_sin32({2'b10, 3'b000, 27'b0}, MID32, "sin32(180)");
    check_sin32({2'b10, 3'b111, 27'b0}, 32'h00000000, "sin32(-max)");

    check_sin16({2'b00, 3'b000, 11'b0}, MID16, "sin16(0)");
    check_sin16({2'b00, 3'b111, 11'b0}, 16'hfffe, "sin16(+max)");

    if (errors)
      $fatal(1, "dds2sin: %0d check(s) failed", errors);
    else
      $display("dds2sin self-check: OK");
  end

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);

    #TEST_DURATION;
    $display("DDS test completed.");
    $finish;
  end
endmodule
