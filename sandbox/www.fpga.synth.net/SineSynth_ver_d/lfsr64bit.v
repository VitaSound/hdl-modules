// Scott R. Gravenhorst 2007
// email: music.maker@gte.net
// noise64bit, a 64 bit LFSR noise source.  Each ena cycle causes 
// the module to send 64 clocks to a 64 bit LFSR thus changing it's 
// output each ena cycle.  
// parameter WIDTH controls the data width of the output
//
module lfsr64bit( out, clk );
  parameter WIDTH = 18;

  output [WIDTH-1:0] out;
  input clk;

  wire clk;
  wire [WIDTH-1:0] out;

  reg [63:0] sr = 64'h461B87AA9928112E;          // 64 millionth iteration after using 64'h0000000000000001 as starting value;

  always @ ( posedge clk ) sr <= {sr[62:0],(( sr[63] ^ sr[62] ) ^ ( sr[60] ^ sr[59] ))} ;  // LFSR XOR logic

  assign out = sr[WIDTH-1:0];
endmodule
