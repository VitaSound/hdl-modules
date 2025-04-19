module generator (
    input wire clk,
    input wire enable, // Входной сигнал для управления
    output reg audio_out
);

    reg [15:0] counter = 0; // Счётчик для деления частоты

    always @(posedge clk) begin
        if (enable) begin
            counter <= counter + 1;
            if (counter >= 1136) begin // Исправленный делитель для 440 Гц
                counter <= 0;
                audio_out <= ~audio_out; // Переключаем меандр
            end
        end else begin
            audio_out <= 0; // Тишина, если enable = 0
        end
    end

endmodule
