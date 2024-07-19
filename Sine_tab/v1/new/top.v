module top (
    input wire CLK,
    input wire [7:0] NOTE,  
    input wire RESET,  
    input wire [2:0] form,  
    input wire [6:0] pulse_width,
    output wire [31:0] DDSout_001,
    output wire [31:0] DDSout_dds31
);

    wire [31:0] ADDER;
    wire [31:0] DDS;

  note2dds_1st_gen n2d(.CLK(CLK), .NOTE(NOTE), .ADDER(ADDER));
  DDS dds2(.CLK(CLK), .RESET(RESET), .ADDER(ADDER), .DDS(DDS));

  form_wave_dds31 fw_dds31(.CLK(CLK), .RESET(RESET), .DDS(DDS), .DDSout_dds31(DDSout_dds31), .form(form), .pulse_width(pulse_width));

endmodule