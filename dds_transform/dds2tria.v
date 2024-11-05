module dds2tria #(parameter WIDTH = 32)(signal_in, signal_out);
    input wire [(WIDTH - 1):0] signal_in;
    output wire [(WIDTH - 1):0] signal_out;

    assign signal_out = (signal_in[(WIDTH - 1)]) ? {-signal_in[(WIDTH - 2):0], 1'b0} : {signal_in[(WIDTH - 2):0], 1'b0};
endmodule
