`timescale 1ns / 1ps

module testbench();
  reg clk;
  reg rst;
  reg [7:0] data;
  reg start;
  wire tx;
  wire busy;

  initial clk = 0;
  always #5 clk = ~clk;

  uart_tx #(.CLK_HZ(16), .BAUD(1)) dut (
    .clk(clk),
    .rst(rst),
    .data(data),
    .start(start),
    .tx(tx),
    .busy(busy)
  );

  integer i;
  integer guard;
  reg [7:0] got;

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);
    rst = 1;
    start = 0;
    data = 8'h90;
    repeat (4) @(posedge clk);
    rst = 0;
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;
    guard = 0;
    while (tx !== 1'b0) begin
      @(posedge clk);
      guard = guard + 1;
      if (guard > 32) $fatal(1, "no start bit");
    end
    got = 8'd0;
    for (i = 0; i < 8; i = i + 1) begin
      repeat (16) @(posedge clk);
      got[i] = tx;
    end
    if (got !== 8'h90) $fatal(1, "uart_tx got %02x", got);
    $display("uart_tx test completed.");
    $finish;
  end
endmodule
