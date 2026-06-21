module adsr_regs_to_ctrl4(
    input  wire [13:0] attack14,
    input  wire [13:0] decay14,
    input  wire [13:0] release14,
    input  wire [6:0]  sustain7,
    output wire [3:0]  a,
    output wire [3:0]  d,
    output wire [3:0]  s,
    output wire [3:0]  r
);

    function [3:0] rate14_to_ctrl4;
        input [13:0] rate;
        begin
            if (rate >= 14'd6000)
                rate14_to_ctrl4 = 4'd15;
            else if (rate >= 14'd3000)
                rate14_to_ctrl4 = 4'd13;
            else if (rate >= 14'd1500)
                rate14_to_ctrl4 = 4'd11;
            else if (rate >= 14'd750)
                rate14_to_ctrl4 = 4'd9;
            else if (rate >= 14'd375)
                rate14_to_ctrl4 = 4'd7;
            else if (rate >= 14'd187)
                rate14_to_ctrl4 = 4'd5;
            else if (rate >= 14'd93)
                rate14_to_ctrl4 = 4'd3;
            else if (rate >= 14'd46)
                rate14_to_ctrl4 = 4'd1;
            else
                rate14_to_ctrl4 = 4'd0;
        end
    endfunction

    assign a = rate14_to_ctrl4(attack14);
    assign d = rate14_to_ctrl4(decay14);
    assign r = rate14_to_ctrl4(release14);
    assign s = sustain7[6:3];

endmodule
