`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Scott R. Gravenhorst
//           music.maker@gte.net
// Create Date:    10:46:50 10/29/2006 
// Design Name: 
// Module Name:    RecursiveFilterMath1Stage 
// Project Name: 
// Description:    Recursive Filter Math Implementation
//                 Current implementation: output = a0 * input_sample + b1 * prev_output
//
// Additional Comments: 
// No data is stored in this module.
// This filter math module uses 36 bit fixed point arithmetic.  The number format is:
//    Sxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//    where S is the sign bit
//      and x is a varying signal bit
//    The "binary point" is assumed to be between the sign bit and the first digit bit.
//    All numbers are between 
//           -.11111111111111111111111111111111111 and +.11111111111111111111111111111111111 binary
//    In some cases, intermediate results are truncated with sign to 18 bits to accomodate the inputs 
//    to the multipliers.
//
//    Since the filter's response to Delay is nonlinear, i.e., there is a more profound change in the 
//    filter's character when the Delay value is closer to 7FFFFFFFF, I have added a 3rd power converter.  
//    This should hopefully do a good enough job at the expense of only two multipliers.  Squaring worked, 
//    but didn't totally fix the problem.  4th power worked best, but with lower resolution, freq value 
//    may vary only between 0 and 430 with stepping at the low end.  Cubing is a reasonable compromise.
//
//    This version of the filter uses a cubic converter to somewhat linearize the frequency
//    input to the filter.  Frequency values are completely arbitrary and can range from
//    0 to 3250.  THE CUBER HAS BEEN MOVED OUTSIDE OF THIS MODULE SO THAT IT CAN BE PIPELINED.  SEE TOP MODULE
//
//    Usually, this type of filter is controlled with a "Delay" value.  Delay, however,
//    works inversely with respect to frequency, so this filter accepts an arbitrary frequency
//    value that is converted to Delay.
//////////////////////////////////////////////////////////////////////////////////

module RecursiveFilterMath1Stage_a( 
  DataIn,
  Delay,
  PrevData,
  DataOut
  );
  
  input signed [17:0] DataIn;    // Data input for one calculation cycle.
  input signed [35:0] Delay;      // Frequency value to use, restrict to range 0 -> 3250
  input signed [17:0] PrevData;  // This is the output from the last calculation cycle and is stored 
                                 // externally to allow multiplexing this module.
  output signed [35:0] DataOut;  // Data output from this calculation cycle.

  wire signed [17:0] DataIn;
  wire signed [35:0] Delay;
  wire signed [17:0] PrevData;
  wire signed [35:0] DataOut;
  
  wire signed [17:0] a0;
  wire signed [17:0] b1;
 
  assign b1 = Delay >>> 18;
  assign a0 = ( 36'sh7FFFFFFFF - Delay ) >>> 18;

// math processes attenuate by 2.  So we multiply by 2 to restore amplitude.  
  assign DataOut = ( DataIn * a0 + PrevData * b1 ) << 1;
  
endmodule
