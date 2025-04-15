`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 1000000;

  wire rst;
  wire signal_out_2;

  reg clk50M;
  initial clk50M <= 0;
  always
    #10 clk50M <= ~clk50M; // Задержка 10 ns (100mhz -  50 mhz clk)

  // 50M / 44100 = 1133.78684807
  frqdivmod #(.DIV(1134)) frqdivmod_44100(
    .clk(clk50M),
    .signal_out(signal_out_2)
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

  initial
  begin
    $dumpfile("out.vcd");
    $dumpvars(0,testbench);

    #TEST_DURATION;
    $display("test completed.");
    $finish;
  end
endmodule
