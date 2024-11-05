// spi_txrx.v: spi shift register for Spartan 3E starter kit
// 2006-06-21 E. Brombaugh

module spi_txrx(clk, reset,
				spi_sck, spi_sdo, spi_sdi, spi_dac_cs,
				ena_out, data_in, data_out);
	input clk;
	input reset;
	output spi_sck;
	output spi_sdo;
	input spi_sdi;
	output spi_dac_cs;
	output ena_out;
	input [23:0] data_in;
	output [23:0] data_out;
	
	// SPI_sck      = 0      Clock is Low (required)
	// SPI_dac_cs   = 1      Deselect D/A
	
	// SPI clock is system clock/2
	reg half_clk;
	always @(posedge clk)
		if(reset)
			half_clk <= 1'b0;
		else
			half_clk <= ~half_clk;
	
	// synchronous counter sequences the spi bits
	reg [5:0] state, next_state;
	always @(posedge clk)
		if(reset)
			state <= 6'd0;
		else
			if(half_clk)
				state <= next_state;
	
	reg ck_ena, sdo, dac_cs;
	
	// compute next state and spi outputs
	always @(state)
	begin
		// defaults
		ck_ena = 1'b1;
		dac_cs = 1'b0;
		sdo = 1'bx;
		next_state = state + 1;
		
		case(state)
			6'd0:	// 1st cycle: CS high
			begin
				ck_ena = 1'b0;
				dac_cs = 1'b1;
			end
			
			6'd24:	// 25th cycle: reset
				next_state = 6'd0;
		endcase
	end
	
	// Data register
	reg [23:0] ser_reg;
	always @(posedge clk)
		if(ck_ena)
		begin	// shift
			if(half_clk)
				ser_reg <= {ser_reg[22:0],spi_sdi};
		end
		else	// load
			ser_reg <= data_in;
	
	// received data
	assign data_out = ser_reg;
	
	// Output registers
	reg spi_sck, spi_sdo, spi_dac_cs, ena_out;
	always @(posedge clk)
	begin
		spi_sck <= half_clk & ck_ena;
		spi_sdo <= ser_reg[23];
		spi_dac_cs <= dac_cs;
		ena_out <= ~half_clk & ~ck_ena;
	end		
endmodule

