// noise64bit, a 64 bit LFSR noise source.  Each ena cycle causes 
// the module to send 64 clocks to a 64 bit LFSR thus changing it's 
// output each ena cycle.  

module noise64bit( out, clk, ena, filter_bw );
  output [17:0] out;
  input clk;
  input ena;
  input [4:0] filter_bw;

  wire clk;
  wire ena;
  wire [4:0] filter_bw;
  wire [17:0] out;

  reg [63:0] sr = 64'h461B87AA9928112E;          // 64 millionth iteration after using 64'h0000000000000001 as starting value;
  reg run = 1'b0;
  reg [4:0] count = 0;

  always @ ( posedge clk )    
  begin
    if ( ena )                                   // each enable, this state machine advances LFSR by 18 bits,
      begin                                      // thus refreshing the output.
	   run <= 1;
      count <= 17;                               // 18 counts, zero counts as first.
      end
    else
      begin
      if ( run )
	     begin
	     sr <= {sr[62:0],(( sr[63] ^ sr[62] ) ^ ( sr[60] ^ sr[59] ))} ;  // LFSR XOR logic
	     count <= count - 1;
	     if ( count == 0 ) run <= 1'b0;           // stop once we've done the zeroth count.
	     end  
      end
  end

  noise_iir #( .dsz(18), .q(31) ) LPF ( .clk( ena ), .bw( filter_bw ), .in( sr[17:0] ), .out( out ) );

endmodule
