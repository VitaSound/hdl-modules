// Title: PW_Interp.v      
// Author: Scott R. Gravenhorst
// Date: 2007-03-02
//
// This module provides interpolation of the pitchwheel table

module PW_Interp ( PW, data_out );
  input [13:0] PW;   // pitch wheel value, unsigned 14 bits
  output [17:0] data_out;

  wire [13:0] PW;
  wire [17:0] data_out;

  wire [3:0] PWHighNybble;
  wire [9:0] PWLowBits;

  wire [16:0] hi, lo;
  
  wire [16:0] dif_HL;
  wire [35:0] prod;
  
  wire [35:0] pre_out;

  assign PWHighNybble = PW[13:10];
  assign PWLowBits    = PW[9:0];

PW_ROM ROM (
    .ad( PWHighNybble ), 
    .out_hi( hi ), 
    .out_lo( lo )
    );

  assign dif_HL = hi - lo ;                      // get difference between hi and lo table values for this note
  assign pre_out = (prod << 8) + (lo << 18) ;    // finish interpolation calc
  assign data_out = pre_out[35:18] ;             // only the upper 18 bits because it is used by another multiplier.

  assign prod = dif_HL * PWLowBits;

endmodule
