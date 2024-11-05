// Adapted by: Scott R. Gravenhorst
// email: music.maker@gte.net
// 2007-03-23
// Derived from code posted to FPGA-Synth by: Eric Brombaugh
//
// IIR filter that requires no dedicated multipliers.
//
// This version is intended for use as an LPF for the noise
// generator LFSRs that modulate pitch.
//
// Modified for larger bw values.
//
// Math Caveats:
//  bw must be <= q
//
// Tried to make bw larger than q -> that can't happen, look at coef, it goes negative, if bw is zero then fb1
// is always zero so there's never any feedback.  This version assumes an input size of 18 bits, but pads
// with zeroes on the right for calculations.  dsz can then be made large.  Module output must then use
// just the upper 18 bits of the ssum1.  Even when q is less than but close to dsz, it looks like there
// can be a loss of precision for fb1.  The intention of this modification is to get more out of the low
// bw end, esp. at zero, to allow very slowly changing values, like a random LFO.  Hopefully it makes for
// weird phasing effects.  The extra register use is not a problem because this project is rather small
// compared to the target FPGA.
//
// add 'sel' to select a feedback register
//
// // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // 
//        The timing report shows that the NzIIR filter is quite slow and causes the timing
//        to almost violate the constraint.  Since this is just a noise timer, there is no reason
//        that it's output should be calculated before it is needed.  In this version, the output
//        is acquired before the enable but after sel has been set.  The calculation is then started
//        by asserting ena after the output has been captured.  This will allow us to change NZIIR
//        to use 3 clocks instead of one without adding another state to NCO_mult's state machine.

module noise_iir( clk, ena, bw, in, sel, out );
  parameter NCOMAX = 3;
  parameter SEL_WIDTH = 2;

  parameter dsz = 18;
 
  parameter q = 31;                  // max coeff - still 15, seems upper end doesn't do much. I'm more interested in lower end.
  parameter isz = dsz+q;             // Accumulator and ssum1 size

  input clk;                             // System clock
  input ena;                             // go signal
  input [4:0] bw;                        // bandwidth
  input signed [dsz-1:0] in;             // Input data
  input [SEL_WIDTH-1:0] sel;             // select one of 4 filters by selecting the feedback RAM 'acc1'.
  output signed [dsz-1:0] out;           // Output data

  reg signed  [isz-1:0] acc1 [NCOMAX:0]; // RAM accumulators
  reg signed  [isz-1:0] acc1_cache;      // cache

  wire [SEL_WIDTH-1:0] sel;

  wire        [5:0]     coef;
  reg  signed [isz:0]   sum1;        // unsaturated sum
  wire signed [isz-1:0] ssum1;       // saturated sum
  wire signed [dsz-1:0] fb1;         // feedback

  assign coef = q - bw;              // compute amount to shift acc1

  assign fb1 = acc1[sel] >>> coef;        // scale feedback
  assign out = fb1;

// Saturate sum
  sat #( .isz(isz+1), .osz(isz)) usat1 ( .in(sum1), .out(ssum1) );

// filter state machine
  reg run = 0;
  reg state = 0;
  always @ ( posedge clk )
    begin
    if ( ena )
      begin
      state      <= 0;
      run        <= 1;
      acc1_cache <= acc1[sel];
      end
    else
      begin
      if ( run )
        begin
        case ( state )
          1'h0:
            begin
            state <= 1;
            sum1 <= in + acc1_cache - fb1;
            end
          1'h1:
            begin
            run <= 0;
            acc1[sel] <= ssum1;
            end
        endcase
        end
      end
    end

endmodule
