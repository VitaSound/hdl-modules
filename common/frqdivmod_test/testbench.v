`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;

  wire rst;
  wire signal_out_2;
  wire signal_out_3;
  wire signal_out_4;

  reg clk50M;
  initial clk50M <= 0;
  always
    #10 clk50M <= ~clk50M; // Задержка 10 ns (100mhz -  50 mhz clk)

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

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);

    #TEST_DURATION;
    $display("test completed.");
    $finish;
  end
endmodule