// Scott R. Gravenhorst
// email: music.maker@gte.net
// 2007-12-06
// 2007-03-11 RAM based for sharing.  GateMan_Id worked with first cut of shared portamento module.
// 2007-03-13 modifying for increased scalability.
//
// This module uses a multiplierless IIR Posted to FPGA-Synth by: Eric Brombaugh
//
// Since it behaves similarly to an RC circuit, it is employed here 
// to generate a portamento effect when a pitch contol value stream
// is passed through it.
//
// To allow control over portamento time, this module provides the clk_div and
// bw inputs.  bw is to be considered a coarse control.  clk_div provides fine 
// control over portamento time through it's use as a clock divider value inside
// the portamento module.
//
// clk_div == 0               divide by 1
// clk_div == 1               divide by 2
// clk_div == 2               divide by 3
// clk_div == 3               divide by 4
// clk_div == 4               divide by 5
//       ... etc.
// This should allow for portamento times up to approx. 400 seconds with 
// bw == 0 and q == 7 assuming clk == 1 MHz.
//
module portamento_multi( clk, portamento_clk, clk_div, bw, in, out, unit );
  parameter SEL_WIDTH = 2;
  parameter NCOMAX    = 3;                          // max NCO number (zero based)

  parameter dsz = 48;                               // input data width
  parameter q = 7;	                                // max coeff
  parameter isz = dsz+q;	                          // Accumulator size

  input           clk;                               // system clock (50 MHz)
  input           portamento_clk;                    // clocks one action by this module
  input           [17:0] clk_div;                    // clock divider input value
  input           [SEL_WIDTH-1:0] unit;                        // Selects NCO on which to operate
  
  input           [2:0] bw;                          // bandwidth (0 = 1580 clocks to settle)
  input signed    [dsz-1:0] in;                      // Input data
  output signed   [dsz-1:0] out;                     // Output data

  wire            clk;
  wire            portamento_clk;
  wire            [SEL_WIDTH-1:0] unit;
  
  wire            [2:0] coef;                        // IIR filter coefficient value
  wire signed     [isz:0] sum;                       // unsaturated sum
  wire signed     [isz-1:0] sat_sum;                 // saturated sum
  wire signed     [dsz-1:0] fb;                      // feedback
  wire signed     [dsz-1:0] out;                     // output
  
  wire            [17:0] clk_div;                    // portamento time  
  reg             [17:0] clk_counter[NCOMAX:0];      // 18 bit unsigned clock counter
  reg             [NCOMAX:0] enables = 0;            // portamento clock enables derived from clk and clk_div

  reg ACCwrite = 0;
  wire [54:0] ACCout;

  reg [54:0] ACCS0 [NCOMAX:0];                       // infer phase accumulator as wide dist. RAM

//  always @ ( posedge clk ) if ( ACCwrite ) ACCS0[unit] <= sat_sum;
  always @ ( posedge ACCwrite ) ACCS0[unit] <= sat_sum;
  assign ACCout = ACCS0[unit];

//////////////////////////////////////////////////////////////////////////////////////	
// IIR 

  assign coef = q - bw;                  // compute shift value
  assign fb = ACCout >>> coef;	         // scale acc by coef to produce feedback value
  assign out = fb;                       // scale output
  assign sum = in + ACCout - fb;	       // form sum

  sat #( .isz(isz+1), .osz(isz) ) usat1 ( .in( sum ), .out( sat_sum ) );	// Saturate sum

//////////////////////////////////////////////////////////////////////////////////////
// This logic generates the variable sample rate clocks for each portamento filter.
// clk_counter is dist. RAM used as a divide down.

  always @ ( posedge clk )            
    begin 
	  if ( enables[unit] ) ACCwrite <= 1;    // if current unit enable is high this clock then give rising edge to RAM WCLK
	  else                 ACCwrite <= 0;    // back to zero
	  end

  always @ ( posedge clk )                 // this block increments each clk divider counter
    begin                                  // and sets the corresponding enable bit when count is reached
    if ( portamento_clk == 1'b1 )
      begin
      clk_counter[unit] <= ( clk_counter[unit] == clk_div ) ? 0 : clk_counter[unit] + 1 ;
      if ( clk_counter[unit] == clk_div ) enables[unit] <= 1;
      end
    else enables[unit] <= 0;
    end

endmodule
