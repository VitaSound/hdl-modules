// Signed 16×16 VCA: unity gain at cv=32767, uint16 output centered at 32768.
module svca16(
    input  wire signed [15:0] in,
    input  wire signed [15:0] cv,
    output wire [15:0]        signal_out
);

    wire signed [31:0] product = in * cv;
    wire signed [31:0] scaled   = product >>> 15;
    wire signed [31:0] biased   = scaled + 32'sd32768;

    assign signal_out =
        (biased < 32'sd0)        ? 16'd0 :
        (biased > 32'sd65535)    ? 16'd65535 :
        biased[15:0];

endmodule
