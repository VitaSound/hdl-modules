module reg_sr(clk, rst, s, r, data_out);
    input  wire clk, rst, s, r;
    output reg  data_out;

    initial
        data_out = 1'b0;

    // reset wins when s and r are both asserted
    always @(posedge clk) begin
        if (rst)
            data_out <= 1'b0;
        else if (r)
            data_out <= 1'b0;
        else if (s)
            data_out <= 1'b1;
    end
endmodule
