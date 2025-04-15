/* ===================
 * Envelope generator
 * ===================
 *
 * Creates an 8-bit ADSR (attack, decay, sustain, release) volume envelope.
 *
 *        ..
 *     A . `. D    S
 *      .    `----------
 *     .                . R
 *    .                  `  .
 *  ---------------------------->
 *                             t
 */
module adsr #(
		parameter lclk = 44100,
		parameter WIDTH = 8,
		parameter ACCUMULATOR_BITS = 26

	)
	(
		clk, reset, low_clk, a, d, s, r, signal_out
	);

	input wire clk, reset, low_clk;
	output reg [(WIDTH - 1):0] signal_out;

	input wire [3:0] a;
	input wire [3:0] d;
	input wire [3:0] s;
	input wire [3:0] r;

	localparam  ACCUMULATOR_SIZE = 2**ACCUMULATOR_BITS;
	localparam  ACCUMULATOR_MAX  = ACCUMULATOR_SIZE-1;

	reg [ACCUMULATOR_BITS:0] accumulator;
	reg [16:0] accumulator_inc;  /* value to add to accumulator */

	localparam OFF     = 3'd0;
	localparam ATTACK  = 3'd1;
	localparam DECAY   = 3'd2;
	localparam SUSTAIN = 3'd3;
	localparam RELEASE = 3'd4;


	reg[2:0] state;

	initial begin
		state <= OFF;
		signal_out <= 0;
		accumulator = 0;
	end


endmodule
