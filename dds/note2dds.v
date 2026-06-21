module note2dds #(
    parameter CLK_HZ       = 50_000_000,
    parameter ADDER_WIDTH  = 32,
    parameter MAX_DIAP     = 10
)(clk, note, adder);
    input  wire clk;
    input  wire [8:0] note;
    output wire [ADDER_WIDTH - 1:0] adder;

    reg [3:0] addr;
    reg [5:0] divider;
    reg [31:0] adder_tbl [0:11];

    function automatic real semitone_hz;
        input integer semitone;
        integer ref_note;
        begin
            ref_note = (MAX_DIAP * 12) + semitone;
            semitone_hz = 440.0 * $pow(2.0, (ref_note - 69.0) / 12.0);
        end
    endfunction

    integer i;
    initial begin
        addr    <= 4'd0;
        divider <= 6'd0;
        for (i = 0; i < 12; i = i + 1)
            adder_tbl[i] <= $rtoi($pow(2.0, ADDER_WIDTH) * semitone_hz(i) / CLK_HZ);
    end

    wire [5:0] diap = (note <  12) ? 6'd00 :
                      (note <  24) ? 6'd01 :
                      (note <  36) ? 6'd02 :
                      (note <  48) ? 6'd03 :
                      (note <  60) ? 6'd04 :
                      (note <  72) ? 6'd05 :
                      (note <  84) ? 6'd06 :
                      (note <  96) ? 6'd07 :
                      (note < 108) ? 6'd08 :
                      (note < 120) ? 6'd09 :
                      (note < 132) ? 6'd10 :
                      (note < 144) ? 6'd11 :
                      (note < 156) ? 6'd12 :
                      (note < 168) ? 6'd13 :
                      (note < 180) ? 6'd14 :
                      (note < 192) ? 6'd15 :
                      (note < 204) ? 6'd16 :
                      (note < 216) ? 6'd17 :
                      (note < 228) ? 6'd18 :
                      (note < 240) ? 6'd19 :
                      (note < 252) ? 6'd20 :
                      (note < 264) ? 6'd21 :
                      (note < 276) ? 6'd22 :
                      (note < 288) ? 6'd23 :
                      (note < 300) ? 6'd24 :
                      (note < 312) ? 6'd25 :
                      (note < 324) ? 6'd26 :
                      (note < 336) ? 6'd27 :
                      (note < 348) ? 6'd28 :
                      (note < 360) ? 6'd29 :
                      (note < 372) ? 6'd30 :
                      (note < 384) ? 6'd31 :
                      (note < 396) ? 6'd32 :
                      (note < 408) ? 6'd33 :
                      (note < 420) ? 6'd34 :
                      (note < 432) ? 6'd35 :
                      (note < 444) ? 6'd36 :
                      (note < 456) ? 6'd37 :
                      (note < 468) ? 6'd38 :
                      (note < 480) ? 6'd39 :
                      (note < 492) ? 6'd40 :
                      (note < 504) ? 6'd41 : 6'd42;

    wire [8:0] c_addr = note - (diap * 9'd12);

    function automatic [ADDER_WIDTH - 1:0] note_hz_adder;
        input [8:0] n;
        real hz;
        begin
            hz = 440.0 * $pow(2.0, (n - 69.0) / 12.0);
            note_hz_adder = $rtoi($pow(2.0, ADDER_WIDTH) * hz / CLK_HZ);
        end
    endfunction

    wire [5:0] shift_amt = (diap > MAX_DIAP) ? 6'd0 : (MAX_DIAP - diap);
    wire [ADDER_WIDTH - 1:0] tbl_adder = adder_tbl[c_addr[3:0]] >> shift_amt;
    wire [ADDER_WIDTH - 1:0] ext_adder = note_hz_adder(note);

    assign adder = (diap > MAX_DIAP) ? ext_adder : tbl_adder;

    always @(posedge clk) begin
        addr    <= c_addr[3:0];
        divider <= shift_amt;
    end
endmodule
