// Adapted as portamento module by: Scott R. Gravenhorst
// 2007-12-06
// 2007-03-11 RAM based for sharing.  GateMan_Id worked with first cut of shared portamento module.
// 2007-03-13 modifying for increased scalability.
//
// Original IIR Posted to FPGA-Synth by: Eric Brombaugh
//
// Single stage IIR filter that requires no dedicated multipliers.
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
module portamento_multi( clk50mhz, portamento_clk, clk_div, bw, in, out, unit );
  parameter dsz = 52;		                     // input data width
  parameter q = 7;	                             // max coeff
  parameter isz = dsz+q;	                     // Accumulator size

  input           clk50mhz;
  input           portamento_clk;                    // clocks one action by this module
  input           [17:0] clk_div;                    // clock divider input value
  input           [1:0] unit;                        // Selects NCO on which to operate
  
  input           [2:0] bw;                          // bandwidth (0 = 1580 clocks to settle)
  input signed    [dsz-1:0] in;                      // Input data
  output signed   [dsz-1:0] out;                     // Output data

  wire            clk50mhz;
  wire            portamento_clk;
  wire            [1:0] unit;
  
  wire            [2:0] coef;                        // IIR filter coefficient value
  wire signed     [isz:0] sum;                       // unsaturated sum
  wire signed     [isz-1:0] sat_sum;                 // saturated sum
  wire signed     [dsz-1:0] fb;                      // feedback
  wire signed     [dsz-1:0] out;                     // output
  
  wire            [17:0] clk_div;                    // portamento time  
  reg             [17:0] clk_counter[3:0];           // 18 bit unsigned clock counter
  reg             [3:0] enables = 4'b0000;           // portamento clock enables derived from clk and clk_div

  reg ACCwrite = 0;
  wire [58:0] ACCout;

// 16 x 52 single port dist. RAM (only 4 locations used), this is the accumulator
  RAM16x59S ACCS0 (
    .WCLK( ACCwrite ), 
    .addr( {2'b00,unit} ), 
    .I( sat_sum ), 
    .O( ACCout )
    );

//////////////////////////////////////////////////////////////////////////////////////	
// IIR Calculation:

  assign coef = q - bw;                  // compute shift value
	
  assign fb = ACCout >>> coef;	        // scale acc by coef to produce feedback value

  assign out = fb;                       // scale output
  assign sum = in + ACCout - fb;	        // form sum

  sat #( .isz(isz+1), .osz(isz) ) usat1 ( .in( sum ), .out( sat_sum ) );	// Saturate sum

//////////////////////////////////////////////////////////////////////////////////////

  always @ ( posedge clk50mhz )            
    begin 
	 if ( enables[unit] ) ACCwrite <= 1;    // if current unit enable is high this clock then give rising edge to RAM WCLK
	 else                 ACCwrite <= 0;    // back to zero
	 end

  always @ ( posedge clk50mhz )            // this block increments each clk divider counter
    begin                                  // and sets the corresponding enable bit when count is reached
    if ( portamento_clk == 1'b1 )
      begin
      if ( clk_counter[unit] == clk_div )
        begin
          clk_counter[unit] <= 0;
			 enables[unit] <= 1;
		  end
      else 
        begin
		  clk_counter[unit] <= clk_counter[unit] + 1;
        end
     end
	  else enables[unit] <= 0;
   end

endmodule
