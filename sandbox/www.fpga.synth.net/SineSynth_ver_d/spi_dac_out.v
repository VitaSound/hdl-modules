// spi_dac_out.v: spi dac driver for Spartan 3E starter kit
// 2006-06-21 E. Brombaugh
//
// Published on www.fpga.synth.net with permission
//

module spi_dac_out(clk, reset, spi_sck, spi_sdo, spi_dac_cs, ena_out, data_in);
	input clk;
	input reset;
	output spi_sck;
	output spi_sdo;
	output spi_dac_cs;
	output ena_out;
	input [11:0] data_in;
	
	wire [3:0] cmd = 4'b0011;	// write & update
	wire [3:0] add = 4'b0000;	// DAC A
	
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
		begin
			if(half_clk)
				ser_reg <= {ser_reg[22:0],1'b0};
		end
		else
			ser_reg <= {cmd,add,data_in,4'h0};
	
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
