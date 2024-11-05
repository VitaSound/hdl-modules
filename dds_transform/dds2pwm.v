module dds2pwm #(parameter WIDTH = 32)(signal_in, pwm, signal_out);
    input wire [(WIDTH - 1):0] signal_in;
    input wire [(7 - 1):0] pwm;
    output wire [(WIDTH - 1):0] signal_out;
   
    assign signal_out = (signal_in[(WIDTH - 1):(WIDTH - 1 - 6)] < pwm) ? {WIDTH{1'b1}} : {WIDTH{1'b0}};

endmodule
