module param_reg #(
    parameter WIDTH = 8,
    parameter [WIDTH - 1:0] INIT = {WIDTH{1'b0}}
)(clk, rst, wr, data_in, data_out);
    input  wire clk, rst, wr;
    input  wire [WIDTH - 1:0] data_in;
    output reg  [WIDTH - 1:0] data_out;

    always @(posedge clk) begin
        if (rst)
            data_out <= INIT;
        else if (wr == 1'b1)
            data_out <= data_in;
    end

    initial
        data_out = INIT;
endmodule
