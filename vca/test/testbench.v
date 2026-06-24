`timescale 1us / 1ns

module testbench();
  parameter WIDTH = 32;
  parameter TEST_DURATION = 1000000;
  reg [WIDTH-1:0] adder_input_1;
  reg [WIDTH-1:0] adder_input_2;
  wire [WIDTH-1:0] dds1_signal_out;
  wire [WIDTH-1:0] dds2_signal_out;
  wire [WIDTH-1:0] tria_signal_out;
  wire [WIDTH-1:0] square_signal_out;
  wire [WIDTH-1:0] vca_signal_out;
  wire [WIDTH-1:0] vcaw_signal_out;
  wire [WIDTH-1:0] vca32_signal_out;
  wire [15:0] svca16_out;

  reg signed [15:0] s16_in;
  reg signed [15:0] s16_cv;

  reg clk;
  initial clk <= 0;
  always
    #10 clk <= ~clk; // Задержка 10 ns (100mhz -  50 mhz clk)

  //make reset signal at begin of simulation
  reg reset;
  initial
  begin
    reset = 1;
    adder_input_1 <= 33333333;
    adder_input_2 <= 3333333;
    #50;
    reset = 0;
  end

  dds #(WIDTH) dds_1(
    .clk(clk),
    .reset(reset),
    .adder(adder_input_1),
    .signal_out(dds1_signal_out)
  );

  dds #(WIDTH) dds_2(
    .clk(clk),
    .reset(reset),
    .adder(adder_input_2),
    .signal_out(dds2_signal_out)
  );

  dds2tria #(WIDTH) dds2tria_1(
    .signal_in(dds2_signal_out),
    .signal_out(tria_signal_out)
  );

  dds2square #(WIDTH) dds2square_1(
    .signal_in(dds1_signal_out),
    .signal_out(square_signal_out)
  );

  svca vca_1(
    .in(square_signal_out[(WIDTH-1):(WIDTH-8)]),
    .cv(tria_signal_out[(WIDTH-1):(WIDTH-8)]),
    .signal_out(vca_signal_out)
  );

  svca_wide vca_2(
    .in(square_signal_out[(WIDTH-1):(WIDTH-8)]),
    .cv(tria_signal_out[(WIDTH-1):(WIDTH-8)]),
    .signal_out(vcaw_signal_out)
  );

  svca32 vca_3(
    .in(square_signal_out),
    .cv(tria_signal_out),
    .signal_out(vca32_signal_out)
  );

  svca16 svca16_1(
    .in(s16_in),
    .cv(s16_cv),
    .signal_out(svca16_out)
  );

  integer svca16_err;

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);

    svca16_err = 0;
    s16_in = 16'sd16384;
    s16_cv = 16'sd32767;
    #1;
    if (svca16_out !== 16'd49151) begin
        $display("FAIL svca16 unity pos: got %0d", svca16_out);
        svca16_err = svca16_err + 1;
    end
    s16_in = -16'sd16384;
    s16_cv = 16'sd32767;
    #1;
    if (svca16_out !== 16'd16384) begin
        $display("FAIL svca16 unity neg: got %0d", svca16_out);
        svca16_err = svca16_err + 1;
    end
    s16_in = 16'sd10000;
    s16_cv = 16'sd0;
    #1;
    if (svca16_out !== 16'd32768) begin
        $display("FAIL svca16 zero cv: got %0d", svca16_out);
        svca16_err = svca16_err + 1;
    end
    if (svca16_err)
      $fatal(1, "svca16: %0d check(s) failed", svca16_err);
    $display("OK svca16 unity/zero gain");

    #TEST_DURATION;
    $display("DDS test completed.");
    $finish;
  end
endmodule