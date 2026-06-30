module lfo #(
    parameter CLK_HZ = 1_000_000
)(clk, rst, rate7, sig_out);

    input  wire       clk;
    input  wire       rst;
    input  wire [6:0] rate7;
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

    wire [31:0] sine_full;
    dds2sin #(.WIDTH(32)) u_sin(
        .signal_in(phase),
        .signal_out(sine_full)
    );

    assign sig_out = sine_full[31:24];

endmodule
