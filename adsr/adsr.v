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
		parameter SAMPLE_CLK_FREQ = 44100,
		parameter WIDTH = 8,
		parameter CTRL_WIDTH = 4,
		parameter ACCUMULATOR_BITS = 16

	)
	(
		clk, rst, low_clk, gate, a, d, s, r, signal_out
	);

	input wire clk, rst, low_clk;
	output wire [(ACCUMULATOR_BITS - 1):0] signal_out;

	input wire gate;
	input wire [(CTRL_WIDTH-1):0] a;
	input wire [(CTRL_WIDTH-1):0] d;
	input wire [(CTRL_WIDTH-1):0] s;
	input wire [(CTRL_WIDTH-1):0] r;

	assign signal_out = accumulator;

	localparam  ACCUMULATOR_SIZE = 2**ACCUMULATOR_BITS;
	localparam  ACCUMULATOR_MAX  = ACCUMULATOR_SIZE-1;

	reg [ACCUMULATOR_BITS-1:0] accumulator;

	localparam OFF     = 3'd0;
	localparam ATTACK  = 3'd1;
	localparam DECAY   = 3'd2;
	localparam SUSTAIN = 3'd3;
	localparam RELEASE = 3'd4;


	reg[2:0] state;

	`define CALCULATE_PHASE_INCREMENT(n) $rtoi(ACCUMULATOR_SIZE / (n * SAMPLE_CLK_FREQ))

	initial begin
		state <= OFF;
		accumulator = 0;
	end

	function [(WIDTH - 1):0] attack_table;
		input [(CTRL_WIDTH-1):0] param;
		begin
			case(param)
				4'b0000: attack_table = `CALCULATE_PHASE_INCREMENT(0.002);  // 33554
				4'b0001: attack_table = `CALCULATE_PHASE_INCREMENT(0.008);
				4'b0010: attack_table = `CALCULATE_PHASE_INCREMENT(0.016);
				4'b0011: attack_table = `CALCULATE_PHASE_INCREMENT(0.024);
				4'b0100: attack_table = `CALCULATE_PHASE_INCREMENT(0.038);
				4'b0101: attack_table = `CALCULATE_PHASE_INCREMENT(0.056);
				4'b0110: attack_table = `CALCULATE_PHASE_INCREMENT(0.068);
				4'b0111: attack_table = `CALCULATE_PHASE_INCREMENT(0.080);
				4'b1000: attack_table = `CALCULATE_PHASE_INCREMENT(0.100);
				4'b1001: attack_table = `CALCULATE_PHASE_INCREMENT(0.250);
				4'b1010: attack_table = `CALCULATE_PHASE_INCREMENT(0.500);
				4'b1011: attack_table = `CALCULATE_PHASE_INCREMENT(0.800);
				4'b1100: attack_table = `CALCULATE_PHASE_INCREMENT(1.000);
				4'b1101: attack_table = `CALCULATE_PHASE_INCREMENT(3.000);
				4'b1110: attack_table = `CALCULATE_PHASE_INCREMENT(5.000);
				4'b1111: attack_table = `CALCULATE_PHASE_INCREMENT(8.000);
				default: attack_table = 65535;
			endcase
		end
	endfunction

	function [(WIDTH - 1):0] decay_release_table;
		input [(CTRL_WIDTH-1):0] param;
		begin
			case(param)
				4'b0000: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.006);
				4'b0001: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.024);
				4'b0010: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.048);
				4'b0011: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.072);
				4'b0100: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.114);
				4'b0101: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.168);
				4'b0110: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.204);
				4'b0111: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.240);
				4'b1000: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.300);
				4'b1001: decay_release_table = `CALCULATE_PHASE_INCREMENT(0.750);
				4'b1010: decay_release_table = `CALCULATE_PHASE_INCREMENT(1.500);
				4'b1011: decay_release_table = `CALCULATE_PHASE_INCREMENT(2.400);
				4'b1100: decay_release_table = `CALCULATE_PHASE_INCREMENT(3.000);
				4'b1101: decay_release_table = `CALCULATE_PHASE_INCREMENT(9.000);
				4'b1110: decay_release_table = `CALCULATE_PHASE_INCREMENT(15.00);
				4'b1111: decay_release_table = `CALCULATE_PHASE_INCREMENT(24.00);
				default: decay_release_table = 65535;
			endcase
		end
	endfunction


	// value to add to accumulator during attack phase
	// calculated from lookup table below based on attack parameter
	reg [(WIDTH - 1):0] attack_step;
	always @(a) begin
		attack_step <= attack_table(a); // convert 4-bit value into phase increment amount
	end

	// value to add to accumulator during decay phase
	// calculated from lookup table below based on decay parameter
	reg [(WIDTH - 1):0] decay_step;
	always @(d) begin
		decay_step <= decay_release_table(d); // convert 4-bit value into phase increment amount
	end

	
	reg [(WIDTH - 1):0] release_inc;
	always @(r) begin
		release_inc <= decay_release_table(r); // convert 4-bit value into phase increment amount
	end


	wire [ACCUMULATOR_BITS-1:0] next_acc_inc = accumulator + attack_step;
	wire [ACCUMULATOR_BITS-1:0] next_acc_dec = accumulator - decay_step;

	wire [ACCUMULATOR_BITS-1:0] sustain_volume;
	assign sustain_volume = s << (ACCUMULATOR_BITS - CTRL_WIDTH);

	assign overflow_max = accumulator > next_acc_inc;
	assign overflow_min = accumulator < next_acc_dec;
	assign upderflow_sust = accumulator < sustain_volume;

	always @(posedge clk) begin
		case (state)
			OFF:
				begin
					if ( gate == 1'b0 ) begin
						state <= OFF;
					end else begin
						if (overflow_max) begin
							state <= RELEASE;
						end else begin
							accumulator <= next_acc_inc;
						end
					end
				end
			ATTACK:
				begin
					if ( gate == 1'b0 ) begin
						state <= RELEASE;
					end else begin
						if (overflow_max) begin
							state <= DECAY;
						end else begin
							accumulator <= next_acc_inc;
						end
					end
				end
			DECAY:
				begin
					if ( gate == 1'b0 ) begin
						state <= RELEASE;
					end else begin
						if (upderflow_sust) begin
							state <= SUSTAIN;
						end else begin
							accumulator <= next_acc_dec;
						end
					end
				end
			SUSTAIN:
				begin
					if ( gate == 1'b0 ) begin
						state <= RELEASE;
					end
				end
			RELEASE:
				begin
					if ( gate == 1'b0 ) begin
						if (overflow_min) begin
							state <= OFF;
							accumulator <= 0;
						end else begin
							accumulator <= next_acc_dec;
						end
					end else begin
						state <= ATTACK;
					end
				end
		endcase
	end

endmodule
