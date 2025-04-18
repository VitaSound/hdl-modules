`timescale 1ns / 1ps

module testbench();
  parameter TEST_DURATION = 1000000;

  wire rst;
  wire signal_out_2;
  wire [23:0] signal_out_3;
  reg key0;
  initial key0 <= 0;

  reg clk50M;
  initial clk50M <= 0;
  always
    #10 clk50M <= ~clk50M; // Задержка 10 ns (100mhz -  50 mhz clk)

  // 50M / 48000 = 1041.66666667
  frqdivmod #(.DIV(1042)) frqdivmod_48000(
    .clk(clk50M),
    .signal_out(signal_out_2)
  );

  wire signal_48strobe;

  strobe_gen strobe_gen_48(
    .clk(clk50M),
    .f(signal_out_2),
    .signal_out(signal_48strobe)
  );


  // генератор сброса
  powerup_reset res_gen(
    .clk(clk50M),
    .key(key0),
    .rst(rst)
  );

  reg [7:0] log_reg;
  initial log_reg <= 0;

  reg [7:0] lookup_table [0:255];
  initial begin
      $readmemh("../exp.rom", lookup_table); // Загрузка таблицы из файла
  end

  always @ (posedge clk50M) begin
    log_reg <= log_reg + 1'b1;
  end

  wire [0:255] dout;
  assign dout = lookup_table[log_reg];

	reg [3:0] a;
	reg [3:0] d;
	reg [3:0] s;
	reg [3:0] r;
	reg gate;
  reg wft;

  initial a <= 4'b0000;
  initial d <= 0;
  initial s <= 4'b0111;
  initial r <= 0;
  initial gate <= 0;
  initial wft <=1;

  adsr adsr_1(
    .clk(clk50M),
    // .low_strobe(signal_48strobe), // ТЕСТ 48000
    .low_strobe(wft || signal_48strobe), // ТЕСТ ВОЛНОФОРМ
    .rst(rst),
    .gate(gate),
    .a(a), .d(d), .s(s), .r(r),
    .signal_out(signal_out_3)
  );

  initial
  begin
    #1000 gate <= 1;
    #10000 gate <= 0;
  
    #5000 gate <= 1;
    #1500 gate <= 0;

    #5000 gate <= 1;
    #3000 gate <= 0;
    #200 gate <= 1;
    #200 gate <= 0;

    #10000 gate <= 1;
    #10000 gate <= 0;
    #1200 gate <= 1;
    #200 gate <= 0;


    #10000 gate <= 1; wft <=0mk;
    #5000 a <= 0; d <= 0;
    #5000 a <= 1; d <= 1;
    #5000 a <= 2; d <= 2;
    #5000 a <= 3; d <= 3;
    #5000 a <= 4; d <= 4;
    #5000 a <= 5; d <= 5;
    #5000 a <= 6; d <= 6;
    #5000 a <= 7; d <= 7;
    #5000 a <= 8; d <= 8;
    #5000 a <= 9; d <= 9;
    #5000 a <= 10; d <= 10;
    #5000 a <= 11; d <= 11;
    #5000 a <= 12; d <= 12;
    #5000 a <= 13; d <= 13;
    #5000 a <= 14; d <= 14;
    #5000 a <= 15; d <= 15;


  end

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);

    #TEST_DURATION;
    $display("test completed.");
    $finish;
  end
endmodule
