`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;

  wire rst;
  wire signal_out_2;
  wire signal_out_3;
  wire signal_out_4;

  wire signal_out_2_up;
  wire signal_out_3_up;
  wire signal_out_4_up;

  reg clk50M;
  initial clk50M <= 0;
  always
    #10 clk50M <= ~clk50M; // Задержка 10 ns (100mhz -  50 mhz clk)

  frqdivmod #(.DIV(20)) frqdivmod_2(
    .clk(clk50M),
    .signal_out(signal_out_2)
  );

  frqdivmod #(.DIV(30)) frqdivmod_3(
    .clk(clk50M),
    .signal_out(signal_out_3)
  );

  frqdivmod #(.DIV(40)) frqdivmod_4(
    .clk(clk50M),
    .signal_out(signal_out_4)
  );

  strobe_gen strobe_gen_1(
    .clk(clk50M),
    .f(signal_out_2),
    .signal_out(signal_out_2_up)
  );

  strobe_gen strobe_gen_2(
    .clk(clk50M),
    .f(signal_out_3),
    .signal_out(signal_out_3_up)
  );

  strobe_gen strobe_gen_3(
    .clk(clk50M),
    .f(signal_out_4),
    .signal_out(signal_out_4_up)
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