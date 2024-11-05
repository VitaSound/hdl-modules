`timescale 1us / 1ns

module testbench();
  parameter WIDTH = 32;
  parameter TEST_DURATION = 1000000;
  reg [WIDTH-1:0] adder_input;
  wire [WIDTH-1:0] signal_out;
  wire [WIDTH-1:0] tria_signal_out;
  wire [WIDTH-1:0] saw_signal_out;
  wire [WIDTH-1:0] revsaw_signal_out;
  wire [WIDTH-1:0] meandr_signal_out;
  wire [WIDTH-1:0] pwm_signal_out;
  
  

  reg clk;
  reg reset;

  always
    #10 clk <= ~clk; // Задержка 10 ns (100mhz -  50 mhz clk)

  //make reset signal at begin of simulation

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
  
  dds2meandr #(WIDTH) dds2meandr_1(
    .signal_in(signal_out),
    .signal_out(meandr_signal_out)
  );

  
  dds2pwm #(WIDTH) dds2pwm_1(
    .signal_in(signal_out),
    .pwm(7'd32), // 25%
    .signal_out(pwm_signal_out)
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