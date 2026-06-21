`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 100000;

  reg clk;
  reg rst;
  reg wr7;
  reg [6:0] data7;
  wire [6:0] out7;
  reg wr14;
  reg [13:0] data14;
  wire [13:0] out14;

  integer errors;

  localparam [6:0] INIT7 = 7'd0;
  localparam [13:0] INIT14 = 14'd7540;

  always #10 clk <= ~clk;

  reg7 #(.INIT(INIT7)) dut7(
    .clk(clk),
    .rst(rst),
    .wr(wr7),
    .data(data7),
    .data_out(out7)
  );

  reg14 #(.INIT(INIT14)) dut14(
    .clk(clk),
    .rst(rst),
    .wr(wr14),
    .data(data14),
    .data_out(out14)
  );

  initial begin
    clk = 0;
    rst = 0;
    wr7 = 0;
    wr14 = 0;
    data7 = 0;
    data14 = 0;
    errors = 0;

    repeat (3) @(posedge clk);

    @(negedge clk);
    wr7 = 1;
    data7 = 7'h7f;
    @(posedge clk);
    @(negedge clk);
    wr7 = 0;
    @(posedge clk);
    if (out7 !== 7'h7f) begin
      $display("FAIL reg7 write: got=%h expect=7f", out7);
      errors = errors + 1;
    end

    repeat (5) @(posedge clk);
    if (out7 !== 7'h7f) begin
      $display("FAIL reg7 hold: got=%h expect=7f", out7);
      errors = errors + 1;
    end

    @(negedge clk);
    wr14 = 1;
    data14 = 14'd1234;
    @(posedge clk);
    @(negedge clk);
    wr14 = 0;
    @(posedge clk);
    if (out14 !== 14'd1234) begin
      $display("FAIL reg14 write: got=%h expect=1234", out14);
      errors = errors + 1;
    end

    repeat (5) @(posedge clk);

    @(negedge clk);
    rst = 1;
    @(posedge clk);
    @(negedge clk);
    rst = 0;
    @(posedge clk);
    if (out7 !== INIT7) begin
      $display("FAIL reg7 rst: got=%h expect=%h", out7, INIT7);
      errors = errors + 1;
    end
    if (out14 !== INIT14) begin
      $display("FAIL reg14 rst: got=%h expect=%h", out14, INIT14);
      errors = errors + 1;
    end

    if (errors)
      $fatal(1, "param_reg: %0d check(s) failed", errors);
    else
      $display("param_reg self-check: OK");
  end

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);

    #TEST_DURATION;
    $display("param_reg test completed.");
    $finish;
  end
endmodule
