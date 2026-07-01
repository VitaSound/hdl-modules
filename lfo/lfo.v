module lfo #(
    parameter CLK_HZ = 1_000_000
)(clk, rst, rate7, shape, sig_out);

    input  wire       clk;
    input  wire       rst;
    input  wire [6:0] rate7;
    input  wire [2:0] shape;
    output wire [7:0] sig_out;

    wire [31:0] adder;
    lfo_rate_lut u_rate_lut(.rate7(rate7), .adder(adder));

    wire [31:0] phase;
    dds #(.WIDTH(32)) u_dds(
        .clk(clk),
        .reset(rst),
        .adder(adder),
        .signal_out(phase)
    );

    localparam SINE     = 3'd0;
    localparam TRIANGLE = 3'd1;
    localparam SAW      = 3'd2;
    localparam RAMP     = 3'd3;
    localparam SQUARE   = 3'd4;

    wire [31:0] sine_full;
    wire [31:0] tri_full;
    wire [31:0] saw_full;
    wire [31:0] ramp_full;
    wire [31:0] square_full;

    dds2sin #(.WIDTH(32)) u_sin(
        .signal_in(phase),
        .signal_out(sine_full)
    );

    dds2tria   #(.WIDTH(32)) u_tri(.signal_in(phase), .signal_out(tri_full));
    dds2saw    #(.WIDTH(32)) u_saw(.signal_in(phase), .signal_out(saw_full));
    dds2revsaw #(.WIDTH(32)) u_ramp(.signal_in(phase), .signal_out(ramp_full));
    dds2square #(.WIDTH(32)) u_square(.signal_in(phase), .signal_out(square_full));

    wire [31:0] shaped_full =
        (shape == TRIANGLE) ? tri_full :
        (shape == SAW)      ? saw_full :
        (shape == RAMP)     ? ramp_full :
        (shape == SQUARE)   ? square_full :
        sine_full;

    assign sig_out = shaped_full[31:24];

endmodule
