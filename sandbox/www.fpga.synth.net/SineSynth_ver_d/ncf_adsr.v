// Title: adsr.v
// Author: Scott R. Gravenhorst
// email: music.maker@gte.net
// Date: 2006-08-13
//
// attack - decay - sustain - release, retriggerable.
// Inputs are GATE, A, D, S, R and clk
// A, D and R represent the Attack rate, Decay rate and Release rate
// respectively.  S is the sustain level input.
//
// 2007-09-20: changed to operate on ena enabled clk to slow it down, resolution at the low end was
//             too low, and high end was uselessly high.

module NCFadsr( out, clk, ena, GATE, A, D, S, R, peak, minval, led );
  output [17:0] out;
  input clk;                             // 50 MHz
  input ena;                             // ena from DAC
  input GATE;                            // GATE signal
  input [13:0] A;
  input [13:0] D;
  input [17:0] S;
  input [13:0] R;
  input [17:0] peak;
  input [13:0] minval;
  output [2:0] led; wire [2:0] led;       // DIAG

  parameter SIZE = 33;

  wire [17:0] out;
  wire clk;                               // 50 MHz
  wire ena;
  wire GATE;                              // GATE signal
  wire [13:0] A;
  wire [13:0] D;
  wire [17:0] S;
  wire [13:0] R;
  wire [17:0] peak;
  wire [13:0] minval;
  
  wire [17:0] min;
  assign min = {minval,4'b0000};
  
  reg [2:0] state = 3'b000;               // state register holds machine state

  reg [SIZE-1:0] OUTreg = 0;              // This is the accumulator/integrator for attack, decay and release
  wire signed [SIZE-1:0] dif0;            // OUTreg - D 
  wire signed [SIZE-1:0] dif1;            // OUTreg - R
  wire        [SIZE-1:0] sum0;            // OUTreg + A
  
  wire [SIZE-1:0] tmp;  

  reg [17:0] peak_reg;
  reg [17:0] min_reg;
  
  always @ ( posedge clk )                // if the input peak value is less than the sustain value
    begin                                 // use the sustain level instead.
    if ( S > peak ) peak_reg <= S;
    else            peak_reg <= peak;

    if ( S < min )  min_reg <= S;
    else            min_reg <= min;
    end

  assign out = OUTreg[SIZE-1:SIZE-18];    // 18 bits.  

  assign tmp = dif0 - S << (SIZE-18);
  assign sum0 = OUTreg + {{SIZE-18{1'b0}},A,4'b0000} ;
  assign dif0 = OUTreg - {{SIZE-18{1'b0}},D,4'b0000} ;
  assign dif1 = OUTreg - {{SIZE-18{1'b0}},R,4'b0000} ;

  assign led = state;
  
// This is a state machine of 5 states, IDLE, ATTACK, DECAY, SUSTAIN and RELEASE.  It is retriggerable at 
// any state.  Input busses A and R define the attack rate and the release rate, these values are added or
// subtracted in states ATTACK and RELEASE respectively.

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
          if ( GATE == 1'b1 ) state <= ATTACK;          // escape IDLE state by setting state to 01 (attack)
          OUTreg <= (min_reg << (SIZE-18));
          end
        
      ATTACK:
          begin                        
          if ( GATE == 1'b0 ) state <= RELEASE;           // if GATE is LOW... advance to state 4 (release)
          else            // GATE is high
            begin
            if ( sum0 < (peak_reg << (SIZE-18)) )               // if increment doesn't cause overflow...
              begin
              OUTreg <= sum0;                             // increment out by A
              end
            else                                          // if increment DOES cause overflow...
              begin                                       // increment would cause overflow
              OUTreg <= (peak_reg << (SIZE-18)) ;                        // so set out = max
              state  <= DECAY ;                           // advance to state 2 (decay)
              end
            end
          end
  
      DECAY:
          begin
          if ( GATE == 1'b1 )
            begin
            if ( dif0 - (S << (SIZE-18)) >= 0 )
              begin
              OUTreg <= dif0;                           // decrement out by D
              end
            else                                        // if decrement DID cause underflow...
              begin
              OUTreg[SIZE-1:SIZE-18] <= S;              // set S value into hi bits of OUTreg
              OUTreg[SIZE-19:0] <= 0;                   // clear the low bits
              state             <= SUSTAIN;             // Go to state 3, SUSTAIN
              end
            end
          else state <= RELEASE;                          // gate went low, move to state 4
          end
     
      SUSTAIN:
          begin
          if ( GATE == 1'b0 ) state <= RELEASE;            // Go to state 4, RELEASE
          end
  
      RELEASE:
          begin
          if ( GATE == 1'b1 )  
            begin
            state <= ATTACK;
            end
          else                   
            begin                ///////////// GATE is LOW
            if ( dif1 > (min_reg << (SIZE-18)) )                   // if decrement DID cause underflow...
              begin
              OUTreg     <= dif1;                          // decrement out by R
              end
            else 
              begin
              OUTreg     <= (min_reg << (SIZE-18));
              state      <= IDLE;                         // state 0, IDLE
              end
            end
          end
      endcase
    end  
  end
  
endmodule
