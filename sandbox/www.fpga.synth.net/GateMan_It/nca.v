`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:50:07 12/17/2006 
// Design Name: 
// Module Name:    nca 
// Project Name: 
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
module nca(datain, ctrl, dataout);
    input signed [17:0] datain;
    input signed [17:0] ctrl;
    output signed [35:0] dataout;

    wire signed [17:0] datain;
    wire signed [17:0] ctrl;
    wire signed [35:0] dataout;

    assign dataout = datain * ctrl;

endmodule
