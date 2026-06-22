`timescale 1us / 1ns

module testbench();
    parameter TEST_DURATION = 500000;

    reg clk;
    reg rst;
    reg byte_valid;
    reg [7:0] byte_in;

    wire midi_command_ready;
    wire [3:0] ch_message;
    wire [3:0] chan;
    wire [6:0] note;
    wire [6:0] lsb;
    wire [6:0] msb;

    initial clk <= 0;
    always #10 clk <= ~clk;

    wire sysex_byte_valid_w;
    wire [7:0] sysex_byte_w;
    wire sysex_done_w;
    wire sysex_overflow_w;

    midi_in dut(
        .clk(clk),
        .rst(rst),
        .byte_valid(byte_valid),
        .byte_in(byte_in),
        .midi_command_ready(midi_command_ready),
        .ch_message(ch_message),
        .chan(chan),
        .note(note),
        .lsb(lsb),
        .msb(msb),
        .sysex_byte_valid(sysex_byte_valid_w),
        .sysex_byte(sysex_byte_w),
        .sysex_done(sysex_done_w),
        .sysex_overflow(sysex_overflow_w)
    );

    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            byte_valid <= 1'b1;
            byte_in    <= b;
            @(posedge clk);
            byte_valid <= 1'b0;
        end
    endtask

    task expect_ready;
        input [3:0] exp_msg;
        input [6:0] exp_lsb;
        input [6:0] exp_msb;
        input [6:0] exp_note;
        begin
            @(posedge clk);
            if (!midi_command_ready) begin
                $display("FAIL: midi_command_ready not asserted");
                $finish(1);
            end
            if (ch_message !== exp_msg) begin
                $display("FAIL ch_message: got=%h expect=%h", ch_message, exp_msg);
                $finish(1);
            end
            if (lsb !== exp_lsb) begin
                $display("FAIL lsb: got=%d expect=%d", lsb, exp_lsb);
                $finish(1);
            end
            if (msb !== exp_msb) begin
                $display("FAIL msb: got=%d expect=%d", msb, exp_msb);
                $finish(1);
            end
            if (exp_msg == 4'h9 || exp_msg == 4'h8 || exp_msg == 4'hA) begin
                if (note !== exp_note) begin
                    $display("FAIL note: got=%d expect=%d", note, exp_note);
                    $finish(1);
                end
            end
        end
    endtask

    integer ready_count;

    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, testbench);

        rst        <= 1'b1;
        byte_valid <= 1'b0;
        byte_in    <= 8'd0;
        ready_count = 0;

        repeat (4) @(posedge clk);
        rst <= 1'b0;

        // Note On ch0: 0x90 0x3C 0x40
        send_byte(8'h90);
        send_byte(8'h3C);
        send_byte(8'h40);
        expect_ready(4'h9, 7'd60, 7'd64, 7'd60);
        ready_count = ready_count + 1;

        // CC 16 val 0: 0xB0 0x10 0x00
        send_byte(8'hB0);
        send_byte(8'h10);
        send_byte(8'h00);
        expect_ready(4'hB, 7'd16, 7'd0, 7'd0);
        ready_count = ready_count + 1;

        // Pitch bend: 0xE0 0x00 0x40
        send_byte(8'hE0);
        send_byte(8'h00);
        send_byte(8'h40);
        expect_ready(4'hE, 7'd0, 7'd64, 7'd0);
        ready_count = ready_count + 1;

        // SysEx discard then Note On
        send_byte(8'hF0);
        send_byte(8'h7E);
        send_byte(8'h7F);
        send_byte(8'h06);
        send_byte(8'h01);
        send_byte(8'hF7);

        repeat (4) @(posedge clk);
        if (midi_command_ready) begin
            $display("FAIL: unexpected ready during/after sysex");
            $finish(1);
        end

        send_byte(8'h90);
        send_byte(8'h3C);
        send_byte(8'h40);
        expect_ready(4'h9, 7'd60, 7'd64, 7'd60);
        ready_count = ready_count + 1;

        $display("OK midi_in_test ready_count=%0d", ready_count);
        #TEST_DURATION;
        $finish;
    end
endmodule
