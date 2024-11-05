`timescale 1ns / 1ps
// Title: adsr.v
// Author: Scott R. Gravenhorst
// email: music.maker@gte.net
// Date: 2006-08-13
//
// attack - decay - sustain - release, retriggerable.
// A, D and R represent the Attack rate, Decay rate and Release rate
// respectively.  S is the sustain level input.

module NCAadsr( out, clk, ena, GATE, A, D, S, R, led );

// SIZE is the word size of the calculations made for the ADSR output.  It
// is adjusted to get the best "feel" from both the low and high ends of
// the range of values for A, D and R.  
  parameter SIZE = 32;
  
  output [17:0] out;
  input clk;                            // 50 MHz
  input ena;
  input GATE;                           // GATE signal
  input [13:0] A;                       // attack rate
  input [13:0] D;                       // decay rate
  input [16:0] S;                       // sustain level
  input [13:0] R;                       // release rate
  
  output [2:0] led; 
  wire [2:0] led;

  wire clk;                             // 50 MHz
  wire ena;
  wire GATE;                            // GATE signal
  wire [13:0] A;
  wire [13:0] D;
  wire [16:0] S;
  wire [13:0] R;
  wire [17:0] out;

  reg [2:0] state = 3'b000;             // state register holds machine state

  reg         [SIZE-1:0] OUTreg = 0;    // This is the accumulator/integrator for attack, decay and release
  wire signed [SIZE-1:0] dif0;          // OUTreg - D 
  wire signed [SIZE-1:0] dif1;          // OUTreg - R
  wire signed [SIZE-1:0] sum0;          // OUTreg + A
  
  assign out = OUTreg[SIZE-1:SIZE-18];  // 18 bits.  
  
  assign sum0 = OUTreg + {{SIZE-18{1'b0}},A,4'b0000} ;
  assign dif0 = OUTreg - {{SIZE-18{1'b0}},D,4'b0000} ;
  assign dif1 = OUTreg - {{SIZE-18{1'b0}},R,4'b0000} ;

  assign led = state;

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
// This is a state machine of 5 states, IDLE, ATTACK, DECAY, SUSTAIN and RELEASE.

  parameter IDLE    = 3'b000;
  parameter ATTACK  = 3'b001;
  parameter DECAY   = 3'b010;
  parameter SUSTAIN = 3'b011;
  parameter RELEASE = 3'b100;

  always @ ( posedge clk )
    begin
    
    if ( ena == 1'b1 )
      begin    

      case ( state )
  
      IDLE: 
        begin
        if ( GATE == 1'b1 ) state <= ATTACK;            // escape IDLE state by setting state to 01 (attack)
        end

      ATTACK:
          begin                        
          if ( GATE == 1'b0 ) 
            begin
            state <= RELEASE;                           // if GATE is LOW... advance to state 4 (release)
            end
          else            // GATE is high
            begin
            if ( sum0 >= 0 )
              begin
              OUTreg     <= sum0;                       // increment out by A
              end
            else                                        // if increment DOES cause overflow...
              begin                                     // increment would cause overflow
              OUTreg     <= {1'b0,{SIZE-1{1'b1}}};                   // so set out = max
              state      <= DECAY;                      // advance to state 2 (decay)
              end
            end
          end
          
      DECAY:
          begin
          if ( GATE == 1'b1 )
            begin
            if ( dif0 > {1'b0,S,{SIZE-18{1'b0}}} )
              begin
              OUTreg <= dif0;                           // decrement out by D
              end
            else                                        // if decrement DID cause underflow...
              begin
              OUTreg     <= {1'b0,S,{SIZE-18{1'b0}}} ;
              state      <= SUSTAIN;
              end
            end
          else 
            begin
            state <= RELEASE;                           // gate went low, move to state 4
            end
          end

     SUSTAIN:                
          begin
          if ( GATE == 1'b0 ) state <= RELEASE;         // Go to state 4, RELEASE
          end
  
      RELEASE:
          begin
          if ( GATE == 1'b1 )  
            begin
            state <= ATTACK;
            end
          else                   
            begin                ///////////// GATE is LOW
            if ( dif1 > 32'sh00000000 )                             // if decrement DID cause underflow...
              begin
              OUTreg     <= dif1;                       // decrement out by R
              end
            else 
              begin
              OUTreg     <= 0;                          // set out = 0
              state      <= IDLE;
              end
            end
          end
      endcase
    end  
  end

endmodule
