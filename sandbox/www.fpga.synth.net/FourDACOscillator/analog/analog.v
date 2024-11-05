// analog.v: analog I/O for Xilinx Spartan 3E starter kit
// 2006-07-02 E. Brombaugh

module analog(clk, spi_sck, spi_sdi, spi_sdo, spi_rom_cs, 
				spi_amp_cs, spi_adc_conv, spi_dac_cs, spi_amp_shdn,
				spi_dac_clr,
				strataflash_oe, strataflash_ce, strataflash_we,
				platformflash_oe, 
				led[7:0], rotary_a, rotary_b, sw);

	input clk;
	output spi_sck;
	output spi_sdi;		// Note: Referenced from the peripheral!
	input spi_sdo;		// Note: Referenced from the peripheral!
	output spi_rom_cs;
	output spi_amp_cs;
	output spi_adc_conv;
	output spi_dac_cs;
	output spi_amp_shdn;
	output spi_dac_clr;
	output strataflash_oe;
	output strataflash_ce;
	output strataflash_we;
	output platformflash_oe;
	output [7:0] led;
	input rotary_a;
	input rotary_b;
	input [3:0] sw;
	
	wire ena;				// SPI output port requests new data for DAC
	wire [7:0] amp;								// 8-bit data to SPI AMP
	wire [11:0] dac_a, dac_b, dac_c, dac_d;		// 12-bit data to SPI DAC
	wire [13:0] adc_a, adc_b;					// 14-bit data from SPI ADC

	// Tie off the flash enables to allow SPI to work
	assign strataflash_oe = 1'b1;
	assign strataflash_ce = 1'b1;
	assign strataflash_we = 1'b1;
  	assign platformflash_oe = 1'b0;
	
	// Tie of other SPI enables to isolate DAC
	assign spi_rom_cs = 1;
	assign spi_amp_shdn = 1;
	assign spi_dac_clr = 1;
	
	// synchronize reset
	wire [3:0] rstd;		// POR delay
	wire reset;				// POR/User reset

	FDCE rst_bit0 (.Q(rstd[0]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(1'b1));
	FDCE rst_bit1 (.Q(rstd[1]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[0]));
	FDCE rst_bit2 (.Q(rstd[2]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[1]));
	FDCE rst_bit3 (.Q(rstd[3]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[2]));

	// hook up reset
	assign reset = ~rstd[3];

	// SPI logic
	spi_io uspi(.clk(clk),
					.reset(reset),
				 	.spi_sck(spi_sck),
					.spi_sdo(spi_sdi),
					.spi_sdi(spi_sdo),
					.spi_dac_cs(spi_dac_cs),
					.spi_amp_cs(spi_amp_cs),
					.spi_adc_conv(spi_adc_conv),
					.ena_out(ena),
					.amp_in(amp),
					.dac_a_in(dac_a),
					.dac_b_in(dac_b),
					.dac_c_in(dac_c),
					.dac_d_in(dac_d),
					.adc_a_out(adc_a),
					.adc_b_out(adc_b));
	
	// decode rotary signals
	wire rotary_event, rotary_left;
	rotary_decode urot(.clk(clk), .rotary_a(rotary_a), .rotary_b(rotary_b),
						.rotary_event(rotary_event), .rotary_left(rotary_left));
					
	// counter generates frequency
	wire [7:0] rot_cnt;
	counter_ud #(.dsz(20))
		udc(.clk(clk), .reset(reset), .ena(rotary_event), .dir(~rotary_left),
			.out(rot_cnt));
	
	// Shift value from rot counter by sw to get freq
	wire [23:0] freq;
	assign freq = {16'h0000,rot_cnt} << sw;
	
	// NCO generates phase from frequency
	wire [23:0] phase;
	nco #(.dsz(24))
		unco(.clk(clk), .reset(reset), .ena(ena), .frq(freq), .phs(phase));
	
	// Sawtooth on DAC A
	assign dac_a = phase[23:12];
	
	// Square wave on DAC B
	assign dac_b = {12{phase[23]}};
	
	// Triangle wave on DAC C
	wire signed [11:0] tri_out;
	tri_gen #(.psz(13), .osz(12))
		utri(.clk(clk), .phs_in(phase[23:11]), .tri_out(tri_out));
	assign dac_c = tri_out^12'h800;	// convert signed to offset binary
	
	// Sine wave on DAC D
	wire signed [17:0] sine_out;
	sine_gen usin(.clk(clk), .phs(dac_a), .sin(sine_out), .cos());
	assign dac_d = sine_out[17:6]^12'h800;
	
	// LEDs	show frequency msbs
	assign led = rot_cnt;
endmodule
