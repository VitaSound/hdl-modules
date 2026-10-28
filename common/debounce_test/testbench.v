`timescale 1ns / 1ps

module testbench();
  parameter TEST_DURATION = 2000;

  reg clk;
  reg rst;
  reg in;
  wire out;

  initial clk <= 0;
  always #5 clk <= ~clk;

  debounce #(.WIDTH(3)) dut (
    .clk(clk),
    .rst(rst),
    .in(in),
    .out(out)
  );

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);
    rst <= 1;
    in <= 0;
    #20;
    rst <= 0;
    #20;
    in <= 1;
    #40;
    if (out !== 1'b0) $fatal(1, "bounced too early");
    #80;
    if (out !== 1'b1) $fatal(1, "did not settle high");
    in <= 0;
    #200;
    if (out !== 1'b0) $fatal(1, "did not settle low");
    $display("debounce test completed.");
    $finish;
  end
endmodule
