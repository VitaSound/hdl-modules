module debounce #(
    parameter WIDTH = 16
) (
    input  wire clk,
    input  wire rst,
    input  wire in,
    output reg  out
);
    reg [WIDTH-1:0] cnt;

    initial begin
        out <= 1'b0;
        cnt <= {WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        if (rst) begin
            out <= 1'b0;
            cnt <= {WIDTH{1'b0}};
        end else if (in == out) begin
            cnt <= {WIDTH{1'b0}};
        end else if (cnt == {WIDTH{1'b1}}) begin
            out <= in;
            cnt <= {WIDTH{1'b0}};
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule
