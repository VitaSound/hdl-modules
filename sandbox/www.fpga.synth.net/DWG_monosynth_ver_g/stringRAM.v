`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:15:18 07/01/2007 
// Design Name: 
// Module Name:    stringRAM 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:     Combine RAM modules to create 2048 location by 18 bit wide RAM
//////////////////////////////////////////////////////////////////////////////////
module DL( clk, WRT, A, I, O );

input clk;
input WRT;
input [10:0] A;
input [17:0] I;
output [17:0] O;

wire clk;
wire WRT;
wire [10:0] A;
wire [17:0] I;
wire [17:0] O;

// RAM initialization "0" by default, so no initialization is present in the code.

defparam RAMLO.WRITE_MODE = "WRITE_FIRST";
RAMB16_S9 RAMLO   
              (   
             .DI(I[7:0]),  // 8-bit data_in bus ([7:0])
			    .DIP(I[8]),   // 1-bit parity data_in
 			    .ADDR(A),     // 11-bit address bus ([10:0])
			    .EN(1'b1),    // enable signal
		 	    .WE(WRT),     // write enable signal
			    .SSR(1'b0),   // set/reset signal
			    .CLK(clk),    // clock signal
			    .DO(O[7:0]),  // 8-bit data_out bus ([7:0])
			    .DOP(O[8])    // 1-bit parity data_out 
			     );

defparam RAMHI.WRITE_MODE = "WRITE_FIRST";
RAMB16_S9 RAMHI   
              (   
             .DI(I[16:9]), // 8-bit data_in bus ([7:0])
			    .DIP(I[17]),  // 1-bit parity data_in
 			    .ADDR(A),        // 11-bit address bus ([10:0])
			    .EN(1'b1),    // enable signal
		 	    .WE(WRT),     // write enable signal
			    .SSR(1'b0),   // set/reset signal
			    .CLK(clk),    // clock signal
			    .DO(O[16:9]), // 8-bit data_out bus ([7:0])
			    .DOP(O[17])   // 1-bit parity data_out 
			     );

endmodule
