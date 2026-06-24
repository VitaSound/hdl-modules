module note_mono(clk, rst, note_on, note_off, all_notes_off, all_sound_off, note, out_note, out_gate);

    input  wire clk, rst, note_on, note_off;
    input  wire       all_notes_off, all_sound_off;
    input  wire [6:0] note;
    output wire [6:0] out_note;
    output wire       out_gate;

    reg [127:0] keys;

    initial keys = 128'd0;

    wire keys_clear = all_notes_off || all_sound_off;

    always @(posedge clk) begin
        if (rst) begin
            keys <= 128'd0;
        end else if (keys_clear) begin
            keys <= 128'd0;
        end else if (note_on) begin
            keys[note] <= 1'b1;
        end else if (note_off) begin
            keys[note] <= 1'b0;
        end
    end

    assign out_gate = |keys;

    wire [127:0] highest_onehot;
    wire [6:0]   highest_note;

    bitscan #(.WIDTH(128)) u_bitscan(
        .in(keys),
        .out(highest_onehot)
    );

    prio_encoder #(.LINES(128)) u_prio(
        .in(highest_onehot),
        .out(highest_note)
    );

    reg [6:0] latched_note;

    always @(posedge clk) begin
        if (rst) begin
            latched_note <= 7'd0;
        end else if (|keys) begin
            latched_note <= highest_note;
        end
    end

    assign out_note = latched_note;

endmodule
