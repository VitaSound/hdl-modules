module uart_tx #(
    parameter CLK_HZ = 50000000,
    parameter BAUD   = 31250,
    parameter DIV    = CLK_HZ / BAUD
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       start,
    output reg        tx,
    output wire       busy
);
    reg [15:0] divcnt;
    reg [3:0]  bitn;
    reg [9:0]  shifter;
    reg        sending;

    assign busy = sending;

    initial begin
        tx <= 1'b1;
        sending <= 1'b0;
        divcnt <= 16'd0;
        bitn <= 4'd0;
        shifter <= 10'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            sending <= 1'b0;
            divcnt <= 16'd0;
            bitn <= 4'd0;
        end else if (!sending) begin
            if (start) begin
                shifter <= {1'b1, data, 1'b0};
                sending <= 1'b1;
                divcnt <= 16'd0;
                bitn <= 4'd0;
                tx <= 1'b0;
            end
        end else if (divcnt != DIV - 1) begin
            divcnt <= divcnt + 1'b1;
        end else begin
            divcnt <= 16'd0;
            tx <= shifter[1];
            shifter <= {1'b1, shifter[9:1]};
            if (bitn == 4'd9) begin
                sending <= 1'b0;
                tx <= 1'b1;
            end else begin
                bitn <= bitn + 1'b1;
            end
        end
    end
endmodule
