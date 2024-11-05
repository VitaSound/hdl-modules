`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Scott Gravenhorst
// email: music.maker@gte.net
// 
// Create Date:    14:14:52 08/25/2007 
// Design Name: 
// Module Name:    DLdRAM256 
// Project Name:   Delay line RAM, 256x18 made from distributed RAMs.
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module DL2048( A, I, O, WRT, clk );
  input clk;
  input [10:0] A;  // address
  input [17:0] I;  // data input
  output [17:0] O; // data output
  input WRT;       // write enable

  wire clk;
  wire [10:0] A;   // address
  wire [17:0] I;   // data input
  wire [17:0] O;   // data output
  wire WRT;        // write enable

  reg [17:0] Z[2047:0];
  always @ ( posedge clk )
    begin
    if ( WRT ) Z[A] <= I;
    end
  assign O = Z[A];

endmodule
