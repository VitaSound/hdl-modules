`timescale 1us / 1ns

module testbench();
  parameter WIDTH = 32;
  parameter TEST_DURATION = 1000000;
  reg [WIDTH-1:0] adder_input;
  wire [WIDTH-1:0] signal_out;

  reg clk;
  initial clk <= 0;
  always
    #10 clk <= ~clk; // Задержка 10 ns (100mhz -  50 mhz clk)

  //make reset signal at begin of simulation
  reg reset;
  initial
  begin
    reset = 1;
    adder_input <= 33333333;
    #50;
    reset = 0;
  end

  dds #(WIDTH) dut(
    .clk(clk),
    .reset(reset),
    .adder(adder_input),
    .signal_out(signal_out)
  );

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);

    #TEST_DURATION;
    $display("DDS test completed.");
    $finish;
  end
endmodule