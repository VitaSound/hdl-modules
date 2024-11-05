// Title: tuning_interp.v      
// Author: Scott R. Gravenhorst
// Date: 2007-01-13
//
// This module provides tuning table interpolation and computations to produce a phase 
// increment value for MIDI note numbers from 0 to 127.
//
// VERSION 2

module tuning_interp_v2( note, data_out, tuning );
  input [3:0] note;                    // note value used to select table entry
  output [35:0] data_out;
  input [14:0] tuning;                 // Interpolation factor
  
  wire [3:0] note;
  wire [35:0] data_out;

  wire [21:0] hi, lo;
  wire [14:0] tuning;
  wire [16:0] dif_HL;
  wire [35:0] prod;

tuning_ROM ROM (
    .addr( note ), 
    .out_hi( hi ), 
    .out_lo( lo )
    );

// NOTE: this subtraction always results in the upper 5 bits being zero.  Thus when the difference is used
// in the multiply operation below, we use only the lower 17 bits.
  assign dif_HL = hi[16:0] - lo[16:0] ;       // get difference between hi and lo table values for this note

  assign prod = dif_HL * tuning ;             // start interpolation calc

  assign data_out = prod + (lo << 13) ;       // finish interpolation calc
  
endmodule
