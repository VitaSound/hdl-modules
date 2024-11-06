module rnd1(clk, signal_out);
  parameter [31:0] INIT_VAL = 31'b0011010100100100110010101110010;
  input wire clk;
  output wire signal_out;

  reg [31:0] d0;

  initial
  begin
    d0 <= INIT_VAL;
  end

  always @(posedge clk) begin 
    d0 <= { d0[30:0], d0[30] ^ d0[27] };
  end

  assign signal_out = d0[5:5];
endmodule
