// Title: adsr.v
// Author: Scott R. Gravenhorst
// Date: 2006-08-13
//
// attack - decay - sustain - release, retriggerable.
// Inputs are GATE, a_rate, d_rate, SUSlev, r_rate and clock
// a_rate, d_rate and r_rate represent the Attack rate, Decay rate and Release rate
// respectively.  SUSlev is the sustain level input.

module nca_adsr( ADSRout, clock, GATE, GATEchgd, a_rate, d_rate, SUSlev, r_rate, led );
  parameter PEAK_VALUE = 38'h1FFFFFFFFF;   // set to default to max usable output with an NCA, NCF will probably want to change this.
  output [17:0] ADSRout;
  input clock;                             // 50 MHz
  input GATE;                              // GATE signal
  input GATEchgd;
  input [17:0] a_rate;
  input [17:0] d_rate;
  input [17:0] SUSlev;
  input [17:0] r_rate;
  
  output [7:0] led; wire [7:0] led;

  wire clock;                             // 50 MHz
  wire GATE;                              // GATE signal
  wire [17:0] a_rate;
  wire [17:0] d_rate;
  wire [17:0] SUSlev;
  wire [17:0] r_rate;
  wire [17:0] ADSRout;
 
 
  reg [2:0] state=3'b000;                 // state register holds machine state
//  reg oldGATE=0;                          // allows detection of GATE state change
  wire GATEchgd;                          // output of XOR gate connected to GATE and oldGATE

  reg [37:0] OUTreg=38'h0;                // This is the accumulator/integrator for attack, decay and release
  wire signed [37:0] dif0;                // OUTreg - d_rate 
  wire signed [37:0] dif1;                // OUTreg - r_rate
  wire        [37:0] sum0;
  
//  assign GATEchgd = GATE ^ oldGATE;       // true whenever gate signal changes state.


  
  
  
  
  
  
  
  wire [37:0] tmp;  
  
  assign ADSRout = OUTreg[37:20];         // ADSRout is 18 bits.  
  
  assign tmp = dif0 - {SUSlev,20'h0};
  assign sum0 = OUTreg + a_rate;
  assign dif0 = OUTreg - d_rate;
  assign dif1 = OUTreg - r_rate;
    
///////////////////////////////////////////////  
  assign led = {5'b0,state};      //////// DIAG 
///////////////////////////////////////////////  

  
// This is a state machine of 5 states, IDLE, ATTACK, DECAY, SUSTAIN and RELEASE.  It is retriggerable at 
// any state.  General speed range can be changed by altering the speed of the input clock.  Input busses 
// a_rate and r_rate define the attack rate and the release rate, these values are added or subtracted in states 
// ATTACK and RELEASE respectively.
  always @ ( posedge clock )
  begin
    
//   oldGATE <= GATE;
  
    case ( state )

    ///////// IDLE   STATE 0   
    3'b000: if ( GATE == 1'b1 ) state <= 3'b001;        // escape IDLE state by setting state to 01 (attack)
      
    ///////// ATTACK  STATE 1
    3'b001:
        begin                        
        if ( GATE == 1'b0 ) state <= 3'b100;            // if GATE is LOW... advance to state 4 (release)
        else            // GATE is high
          begin
          if ( sum0 <= PEAK_VALUE )                     // if increment doesn't cause overflow...
            begin
            OUTreg <= sum0;                             // increment ADSRout by a_rate
            end
          else                                          // if increment DOES cause overflow...
            begin                                       // increment would cause overflow
            OUTreg     <= PEAK_VALUE;                   // so set ADSRout = max
            state      <= 3'b010;                       // advance to state 2 (release)
            end
          end
        end

    //////// DECAY    STATE 2  
    3'b010:
        begin
        if ( GATE == 1'b1 )
          begin
          if ( GATEchgd == 1'b1 ) state <= 3'b001;      // restart by moving to state 1 (attack)
          else
            begin
//            if ( dif0 > {SUSlev,20'h0} )               // if decrement doesn't cause underflow...
            if ( tmp[37] == 1'b0 )
              begin
              OUTreg <= dif0;                           // decrement ADSRout by r_rate
              end
            else                                        // if decrement DID cause underflow...
              begin
              OUTreg     <= {SUSlev,20'h0};             // set ADSRout = 0
              state      <= 3'b011;                     // Go to state 3, SUSTAIN
              end
            end
          end
        else state <= 3'b100;                          // gate went low, move to state 4
        end

    //////// SUSTAIN  STATE 3
	 3'b011:                
        begin
        if ( GATE == 1'b0 ) state <= 3'b100;            // Go to state 4, RELEASE
        end

    //////// RELEASE  STATE 4
    3'b100:
        begin
        if ( GATE == 1'b1 )
          begin                ///////////// GATE IS HIGH
          if ( GATEchgd == 1'b1 ) state <= 3'b001;      // restart by moving to state 1 (attack)
          end
        else                   
          begin                ///////////// GATE is LOW
          if ( dif1[37] == 1'b1 )                       // if decrement DID cause underflow...
            begin
            OUTreg     <= 38'b0;                        // set ADSRout = 0
            state      <= 3'b000;                       // state 0, IDLE
            end
          else OUTreg <= dif1;                          // decrement ADSRout by r_rate
          end
        end
    endcase
  end  
endmodule
