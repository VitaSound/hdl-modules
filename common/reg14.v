module reg14 #(
    parameter [13:0] INIT = 14'd0
)(clk, rst, wr, data, data_out);
    input  wire clk, rst, wr;
    input  wire [13:0] data;
    output wire [13:0] data_out;

    param_reg #(.WIDTH(14), .INIT(INIT)) u (
        .clk(clk),
        .rst(rst),
        .wr(wr),
        .data_in(data),
        .data_out(data_out)
    );
endmodule
