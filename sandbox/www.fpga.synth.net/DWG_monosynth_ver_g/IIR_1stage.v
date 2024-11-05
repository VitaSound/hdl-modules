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
//
//    This version of the filter uses a cubic converter to somewhat linearize the frequency
//    input to the filter.  Frequency values are completely arbitrary and can range from
//    0 to 3250.  THE CUBER HAS BEEN MOVED OUTSIDE OF THIS MODULE SO THAT IT CAN BE PIPELINED.  SEE TOP MODULE
//
//    Usually, this type of filter is controlled with a "DEL" value.  DEL, however,
//    works inversely with respect to frequency, so this filter accepts an arbitrary frequency
//    value that is converted to DEL.
//////////////////////////////////////////////////////////////////////////////////

module IIR( I, DEL, FB, O );
  
  input signed [17:0] I;    // Data input for one calculation cycle.
  input signed [35:0] DEL;  // Frequency value (delay) to use, restrict to range 0 -> 3250
  input signed [17:0] FB;   // This is the output from the last calculation cycle and is stored 
                            // externally to allow multiplexing this module.
  output signed [17:0] O;   // Data output from this calculation cycle.

  wire signed [17:0] I;
  wire signed [35:0] DEL;
  wire signed [17:0] FB;
  wire signed [17:0] O;
  
  wire signed [17:0] a0;
  wire signed [17:0] b1;
 
  assign b1 = DEL >>> 18;
  assign a0 = ( 36'sh7FFFFFFFF - DEL ) >>> 18;

// math processes attenuate by 2.  So we multiply by 2 to restore amplitude.  
//  assign O = ( I * a0 + FB * b1 ) << 1;

   wire [35:0] prodA;
   wire [35:0] prodB;
	
   assign O = ( ( prodA + prodB ) << 1 ) >>> 18;
//   assign O = ( prodA + prodB ) >>> 18;
  
   MULT18X18SIO #(
      .AREG(0), // Enable the input registers on the A port (1=on, 0=off)
      .BREG(0), // Enable the input registers on the B port (1=on, 0=off)
      .B_INPUT("DIRECT"), // B cascade input "DIRECT" or "CASCADE
      .PREG(0)  // Enable the input registers on the P port (1=on, 0=off)
   ) MULTA (
      .BCOUT(), // 18-bit cascade output
      .P(prodA),    // 36-bit multiplier output
      .A(I),    // 18-bit multiplier input
      .B(a0),    // 18-bit multiplier input
      .BCIN(), // 18-bit cascade input
      .CEA(1'b0), // Clock enable input for the A port
      .CEB(1'b0), // Clock enable input for the B port
      .CEP(1'b0), // Clock enable input for the P port
      .CLK(1'b0), // Clock input
      .RSTA(1'b0), // Synchronous reset input for the A port
      .RSTB(1'b0), // Synchronous reset input for the B port
      .RSTP(1'b0)  // Synchronous reset input for the P port
   );

   MULT18X18SIO #(
      .AREG(0), // Enable the input registers on the A port (1=on, 0=off)
      .BREG(0), // Enable the input registers on the B port (1=on, 0=off)
      .B_INPUT("DIRECT"), // B cascade input "DIRECT" or "CASCADE
      .PREG(0)  // Enable the input registers on the P port (1=on, 0=off)
   ) MULTB (
      .BCOUT(), // 18-bit cascade output
      .P(prodB),    // 36-bit multiplier output
      .A(FB),    // 18-bit multiplier input
      .B(b1),    // 18-bit multiplier input
      .BCIN(), // 18-bit cascade input
      .CEA(1'b0), // Clock enable input for the A port
      .CEB(1'b0), // Clock enable input for the B port
      .CEP(1'b0), // Clock enable input for the P port
      .CLK(1'b0), // Clock input
      .RSTA(1'b0), // Synchronous reset input for the A port
      .RSTB(1'b0), // Synchronous reset input for the B port
      .RSTP(1'b0)  // Synchronous reset input for the P port
   );

endmodule
