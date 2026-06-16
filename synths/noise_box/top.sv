module noise_box (
    input  wire       clk,
    input  wire       enable,
    input  wire [6:0] note,
    output wire [15:0] audio_sample
);
    wire [15:0] noise_raw;

    rndx #(.WIDTH(16), .INIT_VAL(32'hA5A51234)) u_noise (
        .clk(clk),
        .signal_out(noise_raw)
    );

    assign audio_sample = enable ? noise_raw : 16'd0;
endmodule
