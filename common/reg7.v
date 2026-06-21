module reg7 #(
    parameter [6:0] INIT = 7'd0
)(clk, rst, wr, data, data_out);
    input  wire clk, rst, wr;
    input  wire [6:0] data;
    output wire [6:0] data_out;

    param_reg #(.WIDTH(7), .INIT(INIT)) u (
        .clk(clk),
        .rst(rst),
        .wr(wr),
        .data_in(data),
        .data_out(data_out)
    );
endmodule
