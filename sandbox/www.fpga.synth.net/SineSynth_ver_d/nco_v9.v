/////////////////////////////////////////////////////////////////////////////////////////////////
// Engineer: Scott R. Gravenhorst 11-19-2006
// email: music.maker@gte.net
// Version 9.0 - 03-10-2007
//
// For sine_synth

module nco_v9( clk, unit, reset, phase_inc, out, nco_ena, DACena, led );

  parameter NCOMAX = 3;
  parameter SEL_WIDTH = 2;
  parameter out_hi_bit = 47;    // This number determines the highest bit we use of the phase accum.
                                // Setting this to a higher value (max = 51) will lower the output frequency
                                // by one octave for each increment of one.

  input clk;                         // system clock
  input [SEL_WIDTH-1:0] unit;        // which unit of the 4 NCOs, adress select for NCO RAM
  input reset;
  input [out_hi_bit:0] phase_inc;    // 48 bit phase increment value input
  output signed [17:0] out;
  input nco_ena;
  input DACena;

  output      [7:0]           led;  
  wire        [7:0]           led;

  wire                        DACena;
  wire        [SEL_WIDTH-1:0] unit;
  wire                        reset;
  wire signed [17:0]          tri_out;
  wire signed [17:0]          tri_tmp;        // output of saw to tri converter mux
  wire signed [17:0]          out;

  wire                        nco_ena;        // clocks the new sum into the accumulator

  wire        [out_hi_bit:0]  phase_inc;
  wire signed [out_hi_bit:0]  PHacc ;

// Infer PA_RAM as distributed RAM
  reg [47:0] PA_RAM[NCOMAX:0];                 // DIST. RAM
  always @ ( posedge clk ) if ( nco_ena ) PA_RAM[unit] <= PHacc + phase_inc;  
  assign PHacc = PA_RAM[unit];

////////////////////////////////////////////////////////////////////////////
// Triangle - output the 17 bits below the sign bit, inverted when sign bit high, not inverted when sign bit low.
  assign tri_tmp = PHacc[out_hi_bit:out_hi_bit] ? ~PHacc[out_hi_bit-1:out_hi_bit-18] : PHacc[out_hi_bit-1:out_hi_bit-18] ;
  assign tri_out = tri_tmp + 18'sb100000000000000000 ;

/////////////////////////////////////////////////////////////////////////////
// SINE LOOKUP TABLE LOGIC

// Sine table logic to convert 1/4 cycle table to full cycle output.
// 1st 1/4 cycle: unmodified tri as address, unmodified LUT as out
// 2nd 1/4 cycle: inverted tri as address, unmodified LUT as out
// Last half cycle of tri provides an already inverted address
// 3rd 1/4 cycle: inverted tri as address (provides non-inverted tri as address), inverted LUT as out
// 4th 1/4 cycle: unmodified tri as address, inverted LUT as out
// for 1st 1/2 cycle, output is unmodified, sign = 0
// for 2nd 1/2 cycle, output is inverted, sign = 1

  wire [9:0] adr;
  wire [17:0] sinT;

  assign adr = tri_out[17] ? ~tri_out[16:7] : tri_out[16:7];        // invert address if tri is negative
  assign out = tri_out[17] ? ~sinT : sinT ;                         // use only 17 bits for now, also use tri sign bit
  
// Sine table, 1024 locations (10 bit address 000-3FF) 18 data bits, 1/4 cycle
  sine_tab SIN ( .CLK( clk ), .A( adr ), .O( sinT ) );

endmodule
