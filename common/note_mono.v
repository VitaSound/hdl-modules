module note_mono(clk, rst, note_on, note_off, note, out_note, out_gate);

    input  wire clk, rst, note_on, note_off;
    input  wire [6:0] note;
    output wire [6:0] out_note;
    output wire       out_gate;

    reg [127:0] keys;

    initial keys = 128'd0;

    always @(posedge clk) begin
        if (rst) begin
            keys <= 128'd0;
        end else if (note_on) begin
            keys[note] <= 1'b1;
        end else if (note_off) begin
            keys[note] <= 1'b0;
        end
    end

    assign out_gate = |keys;

    reg [6:0] highest_note;
    integer k;

    always @* begin
        highest_note = 7'd0;
        for (k = 127; k >= 0; k = k - 1) begin
            if (keys[k]) begin
                highest_note = k[6:0];
            end
        end
    end

    assign out_note = highest_note;

endmodule
