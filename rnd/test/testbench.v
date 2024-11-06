`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;

  wire signal_out_rnd1;
  wire [7:0] signal_out_rnd8;
  wire [3:0] signal_out_rndx;

  reg clk;
  initial clk <= 0;
  always
    #10 clk <= ~clk; // Задержка 10 ns (100mhz -  50 mhz clk)

  //make reset signal at begin of simulation
  reg reset;
  initial
  begin
    reset = 1;
    #50;
    reset = 0;
  end

  rnd1 rnd1_1(
    .clk(clk),
    .signal_out(signal_out_rnd1)
  );

  rnd8 rnd8_1(
    .clk(clk),
    .signal_out(signal_out_rnd8)
  );

  rndx #(.WIDTH(4), .INIT_VAL(32'hF1928374)) rndx_1(
    .clk(clk),
    .signal_out(signal_out_rndx)
  );

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);

    #TEST_DURATION;
    $display("Test completed.");
    $finish;
  end
endmodule