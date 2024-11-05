module dds2saw #(parameter WIDTH = 32)(signal_in, signal_out);
    input wire [(WIDTH - 1):0] signal_in;
    output wire [(WIDTH - 1):0] signal_out;

    assign signal_out = signal_in;
endmodule
