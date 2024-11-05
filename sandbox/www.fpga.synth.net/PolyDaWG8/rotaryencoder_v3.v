// email: music.maker@gte.net
// port from vhdl to verilog by Scott R. Gravenhorst
// Modified for GateMan monosynth by Scott R. Gravenhorst
// 02-19-2007 added pushbuttons.  BTNW to be used for master tune increment amplifier
// ver 3 modified to allow full 15 but (unsigned) output with zero starting value.
/*
--
-- Reference design - Rotary encoder and simple LEDs on Spartan-3E Starter Kit (Revision C)
--
-- Ken Chapman - Xilinx Ltd - November 2005
-- Revised 20th February 2006
------------------------------------------------------------------------------------
-- NOTICE:
--
-- Copyright Xilinx, Inc. 2006.   This code may be contain portions patented by other 
-- third parties.  By providing this core as one possible implementation of a standard,
-- Xilinx is making no representation that the provided implementation of this standard 
-- is free from any claims of infringement by any third party.  Xilinx expressly 
-- disclaims any warranty with respect to the adequacy of the implementation, including 
-- but not limited to any warranty or representation that the implementation is free 
-- from claims of any third party.  Furthermore, Xilinx is providing this core as a 
-- courtesy to you and suggests that you contact all third parties to obtain the 
-- necessary rights to use this implementation.
------------------------------------------------------------------------------------
*/

// instantiation of this module creates the register behind value_out.
// This module allows reversal of counter action.  Some encoders work clockwise, others
// counter clockwise.  Press the rotary knob once and it reverses the action.

module ROTv3( clk, ROTa, ROTb, value_out, BTN_W, reset, cfg );
  input clk;
  input ROTa;
  input ROTb;
  output [14:0] value_out;
  input BTN_W;     // when pushed, causes increment of 64 instead of 1.
  input reset;
  input cfg;       // 1 if clockwise rotary encoder, 0 if counterclockwise rotary encoder.

  wire BTN_W;
  wire reset;
  reg ROTa_in;
  reg ROTb_in;
  wire [1:0] ROTin;
  reg ROTq1;
  reg ROTq2;
  reg delay_ROTq1;
  reg ROTevent;
  reg ROTleft;
  
parameter DEFAULT_VAL = 15'h2000;
  reg [14:0] value_out = DEFAULT_VAL;

  wire [3:0] INCREMENT_SHIFT;

  wire DIR;
  
  assign DIR = cfg;
 
  assign ROTin = {ROTb_in,ROTa_in};   // concatenate rotary input signals to form vector for case construct.

  always @ ( posedge clk )
    begin
    ROTa_in <= ROTa;
	  ROTb_in <= ROTb;

      case ( ROTin )
        2'b00: ROTq1 <= 1'b0;         
        2'b01: ROTq2 <= 1'b0;
        2'b10: ROTq2 <= 1'b1;
        2'b11: ROTq1 <= 1'b1;
      endcase
    end
  
  always @ ( posedge clk )
    begin

    delay_ROTq1 <= ROTq1;

    if ( ROTq1 == 1'b1 && delay_ROTq1 == 1'b0 ) 
  	  begin
      ROTevent <= 1'b1;
      ROTleft <= ROTq2;
      end
    else
      begin
      ROTevent <= 1'b0;
		  end
    end

// Output LED drive to the pins making use of the output flip-flops in input/output blocks.
//assign led = led_drive;

  assign INCREMENT_SHIFT = BTN_W ? 8 : 2 ;          // unpressed = 2, pressed = 8. used as an exponent of 2
  
  always @ ( posedge clk )
    begin
    if ( reset == 1'b1 ) value_out <= DEFAULT_VAL;
    else
      begin
      if ( ROTevent == 1'b1 )
        begin
//      if ( ROTleft == 1'b1 )
        if ( ROTleft == DIR )
          begin
          value_out <= value_out - (1 << INCREMENT_SHIFT);
          end
        else                        
          begin
          value_out <= value_out + (1 << INCREMENT_SHIFT);
          end
        end
      end
    end
  
endmodule
