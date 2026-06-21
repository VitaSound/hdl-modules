`timescale 1us / 1ns

module testbench();
  parameter TEST_DURATION = 100000;

  reg clk;
  reg rst;
  reg s;
  reg r;
  wire gate_out;

  integer errors;

  always #10 clk <= ~clk;

  reg_sr dut(
    .clk(clk),
    .rst(rst),
    .s(s),
    .r(r),
    .data_out(gate_out)
  );

  initial begin
    clk = 0;
    rst = 0;
    s = 0;
    r = 0;
    errors = 0;

    repeat (3) @(posedge clk);

    @(negedge clk);
    s = 1;
    @(posedge clk);
    @(negedge clk);
    s = 0;
    @(posedge clk);
    if (gate_out !== 1'b1) begin
      $display("FAIL reg_sr set: got=%b expect=1", gate_out);
      errors = errors + 1;
    end

    repeat (5) @(posedge clk);

    @(negedge clk);
    r = 1;
    @(posedge clk);
    @(negedge clk);
    r = 0;
    @(posedge clk);
    if (gate_out !== 1'b0) begin
      $display("FAIL reg_sr reset: got=%b expect=0", gate_out);
      errors = errors + 1;
    end

    @(negedge clk);
    s = 1;
    r = 1;
    @(posedge clk);
    @(negedge clk);
    s = 0;
    r = 0;
    @(posedge clk);
    if (gate_out !== 1'b0) begin
      $display("FAIL reg_sr s+r: got=%b expect=0", gate_out);
      errors = errors + 1;
    end

    @(negedge clk);
    s = 1;
    @(posedge clk);
    @(negedge clk);
    s = 0;
    @(posedge clk);
    if (gate_out !== 1'b1) begin
      $display("FAIL reg_sr pre-rst set: got=%b expect=1", gate_out);
      errors = errors + 1;
    end

    @(negedge clk);
    rst = 1;
    @(posedge clk);
    @(negedge clk);
    if (gate_out !== 1'b0) begin
      $display("FAIL reg_sr rst clear: got=%b expect=0", gate_out);
      errors = errors + 1;
    end

    s = 1;
    @(posedge clk);
    if (gate_out !== 1'b0) begin
      $display("FAIL reg_sr rst blocks set: got=%b expect=0", gate_out);
      errors = errors + 1;
    end

    @(negedge clk);
    rst = 0;
    s = 0;
    @(posedge clk);
    if (gate_out !== 1'b0) begin
      $display("FAIL reg_sr after rst: got=%b expect=0", gate_out);
      errors = errors + 1;
    end

    if (errors)
      $fatal(1, "reg_sr: %0d check(s) failed", errors);
    else
      $display("reg_sr self-check: OK");
  end

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);

    #TEST_DURATION;
    $display("reg_sr test completed.");
    $finish;
  end
endmodule
