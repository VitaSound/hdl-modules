// spi_io.v: top-level of SPI I/O for Spartan 3E starter kit
// 2006-07-02 E. Brombaugh

module spi_io(clk, reset, spi_sck, spi_sdo, spi_sdi, spi_dac_cs, spi_amp_cs,
				spi_adc_conv, ena_out, amp_in, dac_a_in, dac_b_in,
				dac_c_in, dac_d_in, adc_a_out, adc_b_out);
	input clk;
	input reset;
	output spi_sck;
	output spi_sdo;
	input spi_sdi;
	output spi_dac_cs;
	output spi_amp_cs;
	output spi_adc_conv;
	output ena_out;
	input [11:0] dac_a_in;
	input [11:0] dac_b_in;
	input [11:0] dac_c_in;
	input [11:0] dac_d_in;
	input [7:0] amp_in;
	output [13:0] adc_a_out;
	output [13:0] adc_b_out;
	
	// tie off the Amp and ADC bits for now
	assign spi_amp_cs = 1'b1;
	assign spi_adc_conv = 1'b0;
	
	// tie off the ADC input data
	assign adc_a_out = 14'h0000;
	assign adc_b_out = 14'h0000;
	
	wire [23:0] data_out;		// RX data
	wire ena_txrx;				// Enable from TXRX module
	
	// output data sequencing
	reg [2:0] state, next_state;
	always @(posedge clk)
		if(reset)
			state <= 3'b000;
		else
			state <= next_state;
	
	// Mux data and compute next state
	reg [23:0] data_in;			// TX data	
	always @(state or ena_txrx or dac_a_in or dac_b_in or dac_c_in or dac_d_in)	
		case(state)
			3'b000:
			begin
				if(ena_txrx)
					next_state = 3'b001;
				else
					next_state = state;
				
				// Write DAC A
				data_in = {4'b0000,4'b0000,dac_a_in,4'h0};
			end
			
			3'b001:
			begin
				if(ena_txrx)
					next_state = 3'b010;
				else
					next_state = state;
				
				// Write DAC B
				data_in = {4'b0000,4'b0001,dac_b_in,4'h0};
			end
			
			3'b010:
			begin
				if(ena_txrx)
					next_state = 3'b011;
				else
					next_state = state;
				
				// Write DAC C
				data_in = {4'b0000,4'b0010,dac_c_in,4'h0};
			end
			
			3'b011:
			begin
				if(ena_txrx)
					next_state = 3'b000;
				else
					next_state = state;
				
				// Write DAC D, Update all DACs
				data_in = {4'b0010,4'b0011,dac_d_in,4'h0};
			end
			
			default:
			begin
				next_state = 3'b000;
			end
		endcase
	
	// Just use old SPI output driver to start
	spi_txrx utxrx(.clk(clk), .reset(reset),
				.spi_sck(spi_sck), .spi_sdo(spi_sdo), .spi_sdi(spi_sdi),
				.spi_dac_cs(spi_dac_cs),
				.ena_out(ena_txrx), .data_in(data_in), .data_out());
	
	// ena_out happens once per cycle
	assign ena_out = (state == 3'b011) & ena_txrx;
endmodule
