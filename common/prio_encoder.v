module prio_encoder #(parameter LINES = 128) (in, out);
    localparam WIDTH = $clog2(LINES);

    input  wire [LINES - 1:0] in;
    output wire [WIDTH - 1:0] out;

    reg [WIDTH - 1:0] out_r;
    integer gi;

    always @* begin
        out_r = {WIDTH{1'b0}};
        for (gi = 0; gi < LINES; gi = gi + 1) begin
            if (in[gi]) begin
                out_r = gi[WIDTH - 1:0];
            end
        end
    end

    assign out = out_r;
endmodule
