module generator_fullrange (
    input  wire       clk,
    input  wire       enable,
    input  wire [6:0] note,
    output reg        audio_out
);

    localparam integer CLK_HZ = 1_000_000;

    reg [15:0] counter;
    reg [15:0] divider;

    function automatic [15:0] note_to_divider;
        input [6:0] n;
        real hz;
        real div;
        integer div_i;
        begin
            hz = 440.0 * $pow(2.0, (n - 69.0) / 12.0);
            if (hz < 1.0)
                hz = 1.0;
            div = CLK_HZ / (2.0 * hz) - 1.0;
            if (div < 0.0)
                div = 0.0;
            else if (div > 65535.0)
                div = 65535.0;
            div_i = $rtoi(div);
            note_to_divider = div_i[15:0];
        end
    endfunction

    always @(*) begin
        divider = note_to_divider(note);
    end

    always @(posedge clk) begin
        if (enable) begin
            counter <= counter + 1;
            if (counter >= divider) begin
                counter <= 0;
                audio_out <= ~audio_out;
            end
        end else begin
            counter <= 0;
            audio_out <= 0;
        end
    end

endmodule
