// noise61bit, a 61 bit LFSR noise source.  Each ena cycle causes 
// the module to send 18 clocks to a 61 bit LFSR thus changing it's 
// output each ena cycle.  

module noise61bit( out, clk, ena, filter_bw );
  output [17:0] out;
  input clk;
  input ena;
  input [4:0] filter_bw;

  wire clk;
  wire ena;
  wire [4:0] filter_bw;
  wire [17:0] out;
  
  reg [60:0] sr = 61'h0C2887F2CB7DB6FE;          // 64 millionth iteration after using 61'h0000000000000001 as starting value;
  reg run = 1'b0;
  reg [4:0] count = 0;

  always @ ( posedge clk )    
  begin
    if ( ena )                                   // each enable, this state machine advances LFSR by 18 bits,
      begin                                      // thus refreshing the output.
	   run <= 1;
      count <= 17;                               // 18 counts, zero counts as last.
      end
    else
      begin
      if ( run )
	     begin
	     sr <= {sr[59:0],(( sr[60] ^ sr[59] ) ^ ( sr[45] ^ sr[44] ))} ;  // LFSR XOR logic
	     count <= count - 1;
	     if ( count == 0 ) run <= 1'b0;           // stop once we've done the zeroth count.
	     end  
      end
  end

  noise_iir #( .dsz(18), .q(31) ) LPF ( .clk( ena ), .bw( filter_bw ), .in( sr[17:0] ), .out( out ) );
  
endmodule
