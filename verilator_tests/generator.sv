module generator (
    input wire clk,
    input wire enable, // Входной сигнал для управления
    input wire [6:0] note, // MIDI note number (0..127)
    output reg audio_out
);

    reg [15:0] counter = 0; // Счётчик для деления частоты
    reg [15:0] divider;
    wire [6:0] note_class = note % 7'd12;

    // Делители для 1 MHz такта, квадрат: fout ~= 1e6 / (2 * (divider + 1))
    // Октава C4..B4 (note class 0..11)
    always @(*) begin
        case (note_class)
            7'd0: divider = 16'd1910; // C
            7'd1: divider = 16'd1803; // C#
            7'd2: divider = 16'd1702; // D
            7'd3: divider = 16'd1606; // D#
            7'd4: divider = 16'd1516; // E
            7'd5: divider = 16'd1431; // F
            7'd6: divider = 16'd1350; // F#
            7'd7: divider = 16'd1275; // G
            7'd8: divider = 16'd1203; // G#
            7'd9: divider = 16'd1135; // A
            7'd10: divider = 16'd1072; // A#
            7'd11: divider = 16'd1011; // B
            default: divider = 16'd1135; // A (fallback)
        endcase
    end

    always @(posedge clk) begin
        if (enable) begin
            counter <= counter + 1;
            if (counter >= divider) begin
                counter <= 0;
                audio_out <= ~audio_out; // Переключаем меандр
            end
        end else begin
            counter <= 0;
            audio_out <= 0; // Тишина, если enable = 0
        end
    end

endmodule
