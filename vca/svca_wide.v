module svca_wide(in, cv, signal_out); //
    parameter WIDTH = 8; //

    input wire [(WIDTH-1):0] in, cv;
    output wire [(WIDTH*2-1):0] signal_out;

    wire signed [(WIDTH):0] s_in = in - 8'd128; // 0..255 -> signed -128..127
    wire signed [(WIDTH):0] s_cv = cv;

    wire signed [(WIDTH*2):0] result_s = s_in * s_cv;
    wire [(WIDTH*2):0]   result_sss = result_s + 16'd32768;
    assign signal_out = result_sss;
endmodule
