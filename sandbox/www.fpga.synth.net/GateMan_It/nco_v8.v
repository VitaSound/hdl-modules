/////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////
// Scott R. Gravenhorst 11-19-2006
// music.maker@gte.net
// Version 8.0 - 03-10-2007
//
// ena triggers a phase increment on posedge of clk, used to synch with DAC module.
// This allows synchronization with the DAC clocking.
// NCO with 3 waveform outputs, sawtooth, triangle and PWM with PWM control.
// Contains an additional register (over ver 2) for phase_inc value, output of the register
// becomes the data source for incrementing the phase accumulator.  This additional register
// allows more than one NCO by using a state machine to clock each NCO phase_inc value via
// signal phase_inc_clk.
//
// Version 4 extends the size of the NCO accumulator by 16 bits to 52 bits so that precision 
// loss at the bass end doesn't cause tuning problems.
// 2007-02-03 tested and works, there is no more pitch distortion at the low end.
// Version 5 removes multiple outputs, replacing with a 2 bit waveform selector
// wave_sel = 2'b00 tri
// wave_sel = 2'b01 saw
// wave_sel = 2'b10 pwm
// wave_sel = 2'b11 sine
//
// Version 8
// 2007-02-21  Add portamento
// 2007-03-10  Addressable register based scalable NCO. add 'unit' input to select one of 4 NCOs.
//             Combines 4 separate NCO modules into one.
// 2007-03-14  Replace addressable registers with Single Port RAM.
//             Remove unnecessary registers and clocks
// 2007-03-16  Add sine table

module nco_v8( clk, unit, reset, phase_inc, out, wave_sel, PWMctrl, nco_clk);
  input clk;                         // system clock
  input [1:0] unit;                  // which unit of the 4 NCOs, address select for NCO RAM
  input reset;
  input [51:0] phase_inc;            // 52 bit phase increment value input
  output signed [17:0] out;
  input [1:0] wave_sel;
  input signed [6:0] PWMctrl;       // level value at which PWM turns on
  input nco_clk;

  wire [1:0] unit;
  wire reset;

  wire signed [17:0] saw_out;
  wire signed [17:0] tri_out;
  wire signed [17:0] pwm_out;
  wire signed [17:0] sin_out;
  
  wire signed [17:0] tri_tmp;        // output of saw to tri converter mux

  wire signed [17:0] wavmux0;
  wire signed [17:0] wavmux1;
  wire signed [17:0] out;

  wire [1:0] wave_sel;

  wire nco_clk;                      // clocks the new sum into the accumulator
  
  wire [51:0] phase_inc;
  wire signed [51:0] phase_accum ;
  wire signed [51:0] new_sum ;
													 
  assign wavmux0 = wave_sel[0] ? saw_out : tri_out;
  assign wavmux1 = wave_sel[0] ? sin_out : pwm_out;
  assign out = wave_sel[1] ? wavmux1 : wavmux0;

  assign new_sum = phase_accum + phase_inc ;

  wire [51:0] RAMinput;
  
  assign RAMinput = reset ? 52'b0 : new_sum ;

  distRAM16x52S PhasAccRAM (
    .WE( 1'b1 ), 
    .WCLK( nco_clk ), 
    .addr( {2'b00,unit} ), 
    .I( RAMinput ), 
    .O( phase_accum )
    );

////////////////////////////////////////////////////////////////////////////
// Connect Outputs

  parameter out_hi_bit = 47;    // This number determines the highest bit we use of the phase accum.
                                // Setting this to a higher value (max = 51) will lower the output frequency
										  // by one octave for each increment of one.

// Sawtooth - output the phase accumulator directly
  assign saw_out = phase_accum[out_hi_bit:out_hi_bit-17];            // grab 18 bits.  

// Triangle - output the 17 bits below the sign bit, inverted when sign bit high, not inverted when sign bit low.
  assign tri_tmp = phase_accum[out_hi_bit:out_hi_bit] ? ~phase_accum[out_hi_bit-1:out_hi_bit-18] : phase_accum[out_hi_bit-1:out_hi_bit-18] ;
  assign tri_out = tri_tmp + 18'sb100000000000000000 ;

// PWM based on tri waveform - if tri waveform value < PWMctrl, then output = -max_val else output = +max_val
  wire [7:0] pwm_sum;       // this calculation prevents cutout
  wire [6:0] pwm_applied;

  assign pwm_sum = {1'b0,PWMctrl} + 8'b00000010 ;
  assign pwm_applied = ( pwm_sum >= 8'b01111111 ) ? 7'b1111111 : pwm_sum[6:0] ;
  assign pwm_out = ( tri_tmp < {1'b0,pwm_applied,10'b0000000000} ) ? 18'sb100000000000000001 : 18'sb011111111111111111 ;  
  
/////////////////////////////////////////////////////////////////////////////
// SINE LOOKUP TABLE LOGIC

  wire [9:0] sin_addr;
  wire [17:0] sinTABout;
  
// Sine table logic to convert 1/4 cycle table to full cycle output.
// 1st 1/4 cycle: unmodified tri as address, unmodified LUT as out
// 2nd 1/4 cycle: inverted tri as address, unmodified LUT as out
// Last half cycle of tri provides an already inverted address
// 3rd 1/4 cycle: inverted tri as address (provides non-inverted tri as address), inverted LUT as out
// 4th 1/4 cycle: unmodified tri as address, inverted LUT as out
// for 1st 1/2 cycle, output is unmodified, sign = 0
// for 2nd 1/2 cycle, output is inverted, sign = 1

  assign sin_addr = tri_out[17] ? ~tri_out[16:7] : tri_out[16:7];    // invert address if tri is negative
  assign sin_out = tri_out[17] ? ~sinTABout[17:0] : sinTABout[17:0] ;    // use only 17 bits for now, also use tri sign bit
  
// Sine table, 1024 locations (10 bits, address 000-3FF) 18 data bits, 1/4 cycle
  sine_tab SINE_TAB (
    .clk( clk ),
    .addr( sin_addr ),          // 10 bits
    .out( sinTABout )         // 18 bits
    );

endmodule
