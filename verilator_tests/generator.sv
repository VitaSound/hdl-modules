module generator #(
    parameter CLK_FREQ = 1000000, // Тактовая частота входного сигнала (1 MHz)
    parameter AUDIO_FREQ = 440   // Желаемая частота меандра (440 Hz)
)(
    input wire clk,               // Входной тактовый сигнал (1 MHz)
    output reg audio_out          // Выходной сигнал (меандр)
);

    localparam integer DIVIDER = CLK_FREQ / AUDIO_FREQ; // Делитель частоты
    reg [31:0] counter = 0;                             // Счетчик

    always @(posedge clk) begin
        if (counter == DIVIDER - 1) begin
            counter <= 0;
            audio_out <= ~audio_out; // Переключение меандра
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
