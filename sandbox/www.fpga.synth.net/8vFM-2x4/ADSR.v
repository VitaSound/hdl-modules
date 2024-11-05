`timescale 1ns / 1ps
// Title: ADSR.v
// Author: Scott R. Gravenhorst
// Date: 2008-04-19
//
// attack - decay - sustain - release, retriggerable.
// A, D and R represent the Attack rate, Decay rate and Release rate
// respectively.  S is the sustain level input.
//
// This version is a RAM based multi ADSR, capable of servicing 32 tone generators.
//
// Requires 3 clocks
//
// 2009-04-04:
//  This is for ver_n, expo/linear selectable release phase.
//  When expo_R == 0, release is linear
//  when expo_R == 1, release is exponential
//
// 2009-04-18:
//  Convert ADSR code to 3 clock single enable using expanded state machine
//  Expand ADSR to support 32 ADSRs instead of 8

module ADSR( out, clk, ena, sel, GATE, A, D, S, R, expo_R );

// SIZE is the word size of the calculations made for the ADSR output.  It
// is adjusted to get the best "feel" from both the low and high ends of
// the range of values for A, D and R.  
  
  parameter ADSR_CNT = 32;
  parameter ADSR_MAX = ADSR_CNT-1;
  
//  parameter SIZE = 32;
  parameter SIZE = 28;

  parameter IDLE    = 3'b000;
  parameter ATTACK  = 3'b001;
  parameter DECAY   = 3'b010;
  parameter SUSTAIN = 3'b011;
  parameter RELEASE = 3'b100;
    
  output [17:0] out;
  input clk;                            // 50 MHz
  input ena;
  input [4:0] sel;                      // This signal selects the ADSR, make sure the bit width accomodates the full range.
  input GATE;                           // GATE signal
  input [13:0] A;                       // attack rate
  input [13:0] D;                       // decay rate
  input [16:0] S;                       // sustain level
  input [13:0] R;                       // release rate
  input expo_R;                         // flag for exponential release, uses R for control 
  
  wire clk;                             // 50 MHz
  wire ena;
  wire [4:0] sel;                       ////////////////////////  MUST ACCOMODATE ADSR_CNT
  wire GATE;                            // GATE signal
  wire [13:0] A;
  wire [13:0] D;
  wire [16:0] S;
  wire [13:0] R;
  wire signed [17:0] out;
  wire expo_R;
  
  reg signed [27:0] OUTregRAM [ADSR_MAX:0];   // This is the accumulator/integrator for attack, decay and release
  reg signed [27:0] OUTreg;                 

  wire signed [27:0] dif0;          // OUTreg - D 
  wire signed [27:0] dif1;          // OUTreg - R
  wire signed [27:0] sum0;          // OUTreg + A
  
  wire signed [27:0] IIR;           // OUTreg * b1

  assign out = OUTreg[27:10];  // 18 bits.  
  
  assign sum0 = OUTreg + {{10{1'b0}},A,4'b0000} ;
  assign dif0 = OUTreg - {{10{1'b0}},D,4'b0000} ;
  assign dif1 = OUTreg - {{10{1'b0}},R,4'b0000} ;
  
  reg signed [17:0] b1;              // for expo release, still works like a rate control, lowest is slowest
  wire signed [17:0] RATE;
  assign RATE = {1'b0,R,3'b000} ;
  
  wire signed [17:0] mA;
  wire signed [35:0] PROD;
  assign mA = OUTreg[27:10];         // make signed 18 bit value for multiplier as upper 18 bits of OUTregRAM value
  assign PROD = mA * b1 ;            // multiply b1 x mA
  assign IIR = PROD[34:7];           // IIR value is 30 bits of PROD excluding bit 35 (bit 34 is also a "sign" bit)

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
// This is a state machine of 5 states, IDLE, ATTACK, DECAY, SUSTAIN and RELEASE.

  reg [11:0] count = 0;
  reg [11:0] countRAM [ADSR_MAX:0];
  
  reg run = 0;
  reg state = 0;                            // state machine state
  reg [2:0] ADSRstateRAM [ADSR_MAX:0];             // state register holds machine state
  reg [2:0] ADSRstate;                      // ADSR state cache
  

  always @ ( posedge clk )
    begin
    if ( ena )
      begin
      OUTreg         <= OUTregRAM[sel];            // get OUTregRAM[] data for selected ADSR
      count          <= countRAM[sel]; 
      ADSRstate      <= ADSRstateRAM[sel];              
      b1             <= (18'sh1FFFF - RATE);
      run            <= 1;
      state     <= 0;
      end
    else
      begin
      if ( run )
        begin
        case ( state )
        1'h0:
          begin  state <= 1'h1;

          case ( ADSRstate )
          IDLE: 
            begin
            if ( GATE == 1'b1 ) ADSRstate <= ATTACK;            // escape IDLE state to ATTACK on GATE high
            else                ADSRstate <= IDLE;
            end
          ATTACK:
              begin                        
              if ( GATE == 1'b0 ) 
                begin
                ADSRstate     <= RELEASE;                           // if GATE is LOW... advance to state 4 (release)
                end
              else            // GATE is high
                begin
                if ( sum0 >= 0 )
                  begin
                  OUTreg      <= sum0;                       // increment out by A
                  ADSRstate   <= ATTACK;                     // remain in ATTACK
                  end
                else                                        // if increment DOES cause overflow...
                  begin                                     // increment would cause overflow
                  OUTreg      <= {1'b0,{27{1'b1}}};          // so set out = max
                  ADSRstate   <= DECAY;                          // advance to state 2 (decay)
                  end
                end
              end
          DECAY:
              begin
              if ( GATE == 1'b1 )
                begin
                if ( dif0 > {1'b0,S,{10{1'b0}}} )
                  begin
                  OUTreg         <= dif0;                           // decrement out by D
                  ADSRstate      <= DECAY;
                  end
                else                                        // if decrement DID cause underflow...
                  begin
                  OUTreg         <= {1'b0,S,{10{1'b0}}} ;
                  ADSRstate      <= SUSTAIN;
                  end
                end
              else 
                begin
                ADSRstate        <= RELEASE;                           // gate went low, move to state 4
                end
              end
          SUSTAIN:                
              begin
              if ( GATE == 1'b0 )   ADSRstate <= RELEASE;         // Go to state 4, RELEASE
              else                  ADSRstate <= SUSTAIN;         // stay in sustain
              end
          RELEASE:
              begin
              if ( GATE == 1'b1 ) 
                begin
                ADSRstate           <= ATTACK;
                end
              else  
                begin                ///////////// GATE is LOW
                if ( expo_R )
                  begin
                  if ( IIR != 30'b000000000000000000000000000000 )    // if decrement DID cause underflow...
                    begin
                    ADSRstate       <= RELEASE;
                    if ( count == 12'h0 ) OUTreg <= IIR ;
                    count <= count + 12'h1;
                    end
                  else 
                    begin
                    OUTreg          <= 0;                          // set out = 0
                    ADSRstate       <= IDLE;
                    end
                  end
                else
                  begin
                  if ( dif1 > 0 )                             // if decrement DID cause underflow...
                    begin
                    ADSRstate       <= RELEASE;
                    OUTreg          <= dif1;                       // decrement out by R
                    end
                  else 
                    begin
                    OUTreg          <= 0;                          // set out = 0
                    ADSRstate       <= IDLE;
                    end
                  end
                end
              end
            endcase
            end

          1'h1:
            begin
            OUTregRAM[sel]     <= OUTreg;
            ADSRstateRAM[sel]  <= ADSRstate;
            countRAM[sel]      <= count;
            run                <= 0;
            end
        endcase
        end
      end
    end

endmodule
