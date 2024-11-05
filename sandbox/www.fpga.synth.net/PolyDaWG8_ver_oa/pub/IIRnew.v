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
//    Usually, this type of filter is controlled with a "DELAY" value.  DELAY, however,
//    works inversely with respect to frequency, so this filter accepts an arbitrary frequency
//    value that is converted to DELAY (DEL).
//
//    20070819: Placed feedback storage inside this module.  This will have to be expanded
//              to share the filter.
//    20070819: Share multiplier.
//    20071117: Shorten state machine from 4 clocks to 3 clocks.
//
//////////////////////////////////////////////////////////////////////////////////

module IIRnew( clk, ena, I, DEL, SEL, O );
  
  input clk;                 // system clock
  input ena;                 // enable transfer to feedback storage
  input signed [17:0] I;     // Data input for one calculation cycle.
  input signed [35:0] DEL;   // Frequency value (delay)
  input [2:0] SEL;           // selected feedback register.  Allows sharing the filter
  output signed [17:0] O;    // Data output from this calculation cycle.

  wire signed [17:0] I;       // filter data input
  wire signed [35:0] DEL;     // delay value
  reg  signed [17:0] FB[7:0]; // feedback registers
  wire signed [17:0] O;       // filter data output valid 3 clocks after ena
  wire [2:0] SEL;             // select feedback register    
  
  wire signed [17:0] a0;
  wire signed [17:0] b1;
 
  assign b1 = DEL >>> 18;
  assign a0 = ( 36'sh7FFFFFFFF - DEL ) >>> 18;

  reg run = 1'b0;              // state machine run flag
  reg state;                   // state machine state
  reg signed [35:0] prodA;     // reg for mult prodA output
  reg signed [17:0] mA;       // connects to shared multiplier A input
  reg signed [17:0] mB;       // connects to shared multiplier B input
  wire signed [35:0] P;        // connects to shared multiplier P output
 
  assign O = FB[SEL];  
  
// state machine for sharing multiplier.  Requires 3 clocks.
  always @ ( posedge clk )
    begin
    if ( ena )
      begin
      run <= 1'b1;          // turn state machine on
      state <= 1'b0;        // start at state zero
      mA <= a0;             // set first term multiplier A value
      mB <= I;              // set first term multiplier B value
      end      

    else

      begin
      if ( run )
        begin
        
        state <= state + 1;
        
        case ( state )
        1'b0:
          begin
          prodA <= P ;                      // capture prodA = I * a0
          mA <= b1;                         // set second term multiplier A value
          mB <= FB[SEL];                    // set second term multiplier B value
          end

        1'b1:                               // Note that in this state, P represents prodB
          begin
          FB[SEL] <= ( prodA + P ) >>> 17;  // capture output which is also feedback data.
          run <= 1'b0;                      // turn state machine off
          end
        endcase
        
        end
      end
    end
    
    assign P = mA * mB;                     // Shared 18x18 signed multiplier
    
endmodule

