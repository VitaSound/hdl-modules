module mini_fx (
    input  wire        clk,
    input  wire        rst,
    input  wire        byte_valid,
    input  wire [7:0]  byte_in,
    input  wire        audio_in_valid,
    input  wire signed [15:0] audio_in,
    output wire [15:0] audio_sample,
    output wire        audio_valid
);

    localparam integer CLK_HZ   = 1_000_000;
    localparam integer AUDIO_HZ = 44_100;

    wire       midi_command_ready;
    wire [3:0] ch_message;
    wire [3:0] chan;
    wire [6:0] note_field;
    wire [6:0] lsb;
    wire [6:0] msb;

    wire sysex_byte_valid_unused;
    wire [7:0] sysex_byte_unused;
    wire sysex_done_unused;
    wire sysex_overflow_unused;
    wire       sys_rt_valid;
    wire [7:0] sys_rt_byte;

    midi_in u_midi_in(
        .clk(clk),
        .rst(rst),
        .byte_valid(byte_valid),
        .byte_in(byte_in),
        .midi_command_ready(midi_command_ready),
        .ch_message(ch_message),
        .chan(chan),
        .note(note_field),
        .lsb(lsb),
        .msb(msb),
        .sysex_byte_valid(sysex_byte_valid_unused),
        .sysex_byte(sysex_byte_unused),
        .sysex_done(sysex_done_unused),
        .sysex_overflow(sysex_overflow_unused),
        .sys_rt_valid(sys_rt_valid),
        .sys_rt_byte(sys_rt_byte)
    );

    wire cc_evt = midi_command_ready && (ch_message == 4'hB);
    wire cc121  = cc_evt && (lsb == 7'd121);
    wire fcut_msb_wr = cc_evt && (lsb == 7'd74);
    wire fcut_lsb_wr = cc_evt && (lsb == 7'd106);
    wire fres_wr     = cc_evt && (lsb == 7'd71);

    reg [13:0] fcut14;
    initial fcut14 = 14'd8192;

    always @(posedge clk) begin
        if (cc121)
            fcut14 <= 14'd8192;
        else if (fcut_msb_wr) begin
            fcut14[13:7] <= msb;
            fcut14[6:0]  <= msb;
        end else if (fcut_lsb_wr)
            fcut14[6:0] <= msb;
    end

    wire [6:0] fres7;
    reg7 #(.INIT(7'd0)) u_fres_reg(
        .clk(clk),
        .rst(1'b0),
        .wr(fres_wr | cc121),
        .data(cc121 ? 7'd0 : msb),
        .data_out(fres7)
    );

    wire [6:0] fres_cc = 7'd127 - fres7;

    wire [17:0] svf_f;
    wire [17:0] svf_q;
    svf_cutoff14_to_f u_svf_fc(.idx(fcut14), .f(svf_f));
    svf_cc_to_q u_svf_fq(.cc(fres_cc), .q(svf_q));

    reg [31:0] audio_acc;
    reg        audio_tick;

    always @(posedge clk) begin
        if (rst) begin
            audio_acc  <= 32'd0;
            audio_tick <= 1'b0;
        end else begin
            audio_tick <= 1'b0;
            if (audio_acc + AUDIO_HZ >= CLK_HZ) begin
                audio_acc  <= audio_acc + AUDIO_HZ - CLK_HZ;
                audio_tick <= 1'b1;
            end else begin
                audio_acc <= audio_acc + AUDIO_HZ;
            end
        end
    end

    wire signed [15:0] lp_out;
    wire signed [15:0] hp_unused;
    wire signed [15:0] bp_unused;
    wire signed [15:0] notch_unused;
    svf u_svf(
        .clk(clk),
        .rst(rst),
        .tick(audio_tick && audio_in_valid),
        .f(svf_f),
        .q(svf_q),
        .in(audio_in),
        .hp(hp_unused),
        .bp(bp_unused),
        .lp(lp_out),
        .notch(notch_unused)
    );

    reg [15:0] out_sample;
    reg        out_valid;

    always @(posedge clk) begin
        if (rst) begin
            out_sample <= 16'd32768;
            out_valid  <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (audio_tick && audio_in_valid) begin
                out_sample <= lp_out + 16'd32768;
                out_valid  <= 1'b1;
            end
        end
    end

    assign audio_sample = out_sample;
    assign audio_valid  = out_valid;

endmodule
