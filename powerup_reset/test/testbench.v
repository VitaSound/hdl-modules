`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;

  wire rst;
  reg key0;
  initial key0 <= 0;

  reg clk50M;
  initial clk50M <= 0;
  always
    #10 clk50M <= ~clk50M; // Задержка 10 ns (100mhz -  50 mhz clk)

  // генератор сброса
  powerup_reset res_gen(
    .clk(clk50M),
    .key(key0),
    .rst(rst)
  );

  initial
  begin
    key0 <= 0;
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);
    #1300
    key0 <= 1; // reset key pressed
    #100;
    key0 <= 0;

    #TEST_DURATION;
    $display("RST test completed.");
    $finish;
  end
endmodule