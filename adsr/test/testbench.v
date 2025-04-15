`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;

  wire rst;
  wire signal_out_2;
  wire [15:0] signal_out_3;
  reg key0;
  initial key0 <= 0;

  reg clk50M;
  initial clk50M <= 0;
  always
    #10 clk50M <= ~clk50M; // Задержка 10 ns (100mhz -  50 mhz clk)

  // 50M / 44100 = 1133.78684807
  frqdivmod #(.DIV(1134)) frqdivmod_44100(
    .clk(clk50M),
    .signal_out(signal_out_2)
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

  initial a <= 0;
  initial d <= 0;
  initial s <= 4'b0111;
  initial r <= 0;
  initial gate <= 0;

  adsr adsr_1(
    .clk(clk50M),
    .low_clk(signal_out_2),
    .rst(rst),
    .gate(gate),
    .a(a), .d(d), .s(s), .r(r),
    .signal_out(signal_out_3)
  );

  initial
  begin
    #1000 gate <= 1;
    // #1500 gate <= 0;
    #50000 gate <= 0;
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
