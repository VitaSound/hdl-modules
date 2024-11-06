module rnd8(clk, signal_out);
  parameter [31:0] INIT_VAL_0 = 31'b0011010100100100110010101110010;
  parameter [31:0] INIT_VAL_1 = 31'b0101010101010010101010010110010;
  parameter [31:0] INIT_VAL_2 = 31'b0101010010101010101010100101010;
  parameter [31:0] INIT_VAL_3 = 31'b0101010011001100101010110010101;
  parameter [31:0] INIT_VAL_4 = 31'b0101010010101010101011001010110;
  parameter [31:0] INIT_VAL_5 = 31'b1001001011001010100101101010100;
  parameter [31:0] INIT_VAL_6 = 31'b0101010100100110100101010101010;
  parameter [31:0] INIT_VAL_7 = 31'b0101010010101010110100101010101;

  input wire clk;
  output wire [7:0] signal_out;

  reg [31:0] d0, d1, d2, d3, d4, d5, d6, d7;


  initial
  begin
    d0 <= INIT_VAL_0;
    d1 <= INIT_VAL_1;
    d2 <= INIT_VAL_2;
    d3 <= INIT_VAL_3;
    d4 <= INIT_VAL_4;
    d5 <= INIT_VAL_5;
    d6 <= INIT_VAL_6;
    d7 <= INIT_VAL_7;
  end

  always @(posedge clk) begin 
    d0 <= { d0[30:0], d0[30] ^ d0[27] };
    d1 <= { d1[30:0], d1[30] ^ d1[27] };
    d2 <= { d2[30:0], d2[30] ^ d2[27] };
    d3 <= { d3[30:0], d3[30] ^ d3[27] };
    d4 <= { d4[30:0], d4[30] ^ d4[27] };
    d5 <= { d5[30:0], d5[30] ^ d5[27] };
    d6 <= { d6[30:0], d6[30] ^ d6[27] };
    d7 <= { d7[30:0], d7[30] ^ d7[27] };
  end

  assign signal_out = {d0[5:5],d1[5:5],d2[5:5],d3[5:5],d4[5:5],d5[5:5],d6[5:5],d7[5:5]};
endmodule