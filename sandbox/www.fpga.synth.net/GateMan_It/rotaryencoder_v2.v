// port from vhdl to verilog by Scott R. Gravenhorst
// Modified for GateMan monosynth by Scott R. Gravenhorst
// 02-19-2007 added pushbuttons.  BTN_WEST to be used for master tune increment amplifier

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

module RotaryEncoder_v2( clk, rotary_a, rotary_b, rotary_press, value_out, rotary_press_out, BTN_WEST );
  input clk;
  input rotary_a;
  input rotary_b;
  input rotary_press;
  output [14:0] value_out;
  output rotary_press_out;
  input BTN_WEST;     // master tune multiplier, when pushed, causes increment of 64 instead of 1.

  parameter MAXVALUE = 16384;
  parameter HALFMAX = MAXVALUE/2;

  wire BTN_WEST;
  
  reg rotary_a_in;
  reg rotary_b_in;
  reg rotary_press_in;
  wire [1:0] rotary_in;
  reg rotary_q1;
  reg rotary_q2;
  reg delay_rotary_q1;
  reg rotary_event;
  reg rotary_left;
  reg [14:0] value_out = HALFMAX;

  wire [2:0] INCREMENT_SHIFT;

  assign rotary_in = {rotary_b_in,rotary_a_in};   // concatinate rotary input signals to form vector for case construct.

  assign rotary_press_out = rotary_press_in;

  always @ ( posedge clk )
  begin
    rotary_a_in <= rotary_a;
	 rotary_b_in <= rotary_b;
	 rotary_press_in <= rotary_press;

      case ( rotary_in )
        2'b00: rotary_q1 <= 1'b0;         
        2'b01: rotary_q2 <= 1'b0;
        2'b10: rotary_q2 <= 1'b1;
        2'b11: rotary_q1 <= 1'b1;
      endcase

  end
  
  always @ ( posedge clk )
  begin

    delay_rotary_q1 <= rotary_q1;

    if ( rotary_q1 == 1'b1 && delay_rotary_q1 == 1'b0 ) 
  	   begin
        rotary_event <= 1'b1;
        rotary_left <= rotary_q2;
      end
    else
      begin
        rotary_event <= 1'b0;
		end
  end

// Output LED drive to the pins making use of the output flip-flops in input/output blocks.
//assign led = led_drive;

  assign INCREMENT_SHIFT = BTN_WEST ? 5 : 0 ;          // unpressed = 0, pressed = 5
  
  always @ ( posedge clk )
    begin
        if ( rotary_press_in == 1'b1 ) value_out <= HALFMAX;    // rotary push resets to center tuning.
        if ( rotary_event == 1'b1 )
		  begin
          if ( rotary_left == 1'b1 )
          begin
            if ( value_out > 0 ) value_out <= value_out - (1 << INCREMENT_SHIFT);       // left  - dec
            else value_out <= MAXVALUE;
          end

          else                        
          begin
            if ( value_out < MAXVALUE ) value_out <= value_out + (1 << INCREMENT_SHIFT); // right - inc
            else value_out <= 0;
          end
        end
    end
  
endmodule
