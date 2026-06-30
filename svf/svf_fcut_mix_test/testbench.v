`timescale 1ns / 1ps

module testbench();

    reg [13:0] manual14;
    reg [6:0]  note;
    reg [6:0]  keyfollow7;
    reg [7:0]  lfo_sig;
    reg [6:0]  lfo_depth7;
    reg [15:0] env_u16;
    reg [6:0]  env_amount7;
    wire [13:0] fcut14_out;

    reg [6:0] exp_note;
    wire [13:0] exp_note_idx;
    wire [13:0] exp_ref_idx;

    integer errors;
    integer n;
    integer prev_out;
    integer out_val;
    integer monotone_ok;

    svf_fcut_mix dut(
        .manual14(manual14),
        .note(note),
        .keyfollow7(keyfollow7),
        .lfo_sig(lfo_sig),
        .lfo_depth7(lfo_depth7),
        .env_u16(env_u16),
        .env_amount7(env_amount7),
        .fcut14_out(fcut14_out)
    );

    note_fcut_lut u_exp_note(.note(exp_note), .idx(exp_note_idx));
    note_fcut_lut u_exp_ref(.note(7'd60), .idx(exp_ref_idx));

    function [13:0] clamp14;
        input signed [15:0] v;
        begin
            if (v < 16'sd0)
                clamp14 = 14'd0;
            else if (v > 16'sd16383)
                clamp14 = 14'd16383;
            else
                clamp14 = v[13:0];
        end
    endfunction

    task compute_keyfollow_expect;
        input [13:0] manual;
        input [6:0]  n;
        input [6:0]  kf;
        output [13:0] expect;
        reg signed [14:0] delta;
        reg signed [21:0] wide;
        reg signed [14:0] track;
        begin
            exp_note = n;
            #0;
            delta = $signed({1'b0, exp_note_idx}) - $signed({1'b0, exp_ref_idx});
            wide = delta * $signed({1'b0, kf});
            track = wide >>> 7;
            expect = clamp14($signed({2'b0, manual}) + track);
        end
    endtask

    task expect_eq;
        input [13:0] expect;
        input [255:0] label;
        begin
            if (fcut14_out !== expect) begin
                $display("FAIL svf_fcut_mix %s: got %0d expect %0d", label, fcut14_out, expect);
                errors = errors + 1;
            end else begin
                $display("OK svf_fcut_mix %s", label);
            end
        end
    endtask

    task expect_keyfollow;
        input [13:0] manual;
        input [6:0]  n;
        input [6:0]  kf;
        input [255:0] label;
        reg [13:0] expect;
        begin
            manual14 = manual;
            note = n;
            keyfollow7 = kf;
            lfo_sig = 8'd128;
            lfo_depth7 = 7'd0;
            #1;
            compute_keyfollow_expect(manual, n, kf, expect);
            if (fcut14_out !== expect) begin
                $display("FAIL svf_fcut_mix %s: note=%0d kf=%0d got %0d expect %0d",
                         label, n, kf, fcut14_out, expect);
                errors = errors + 1;
            end else begin
                $display("OK svf_fcut_mix %s (note=%0d kf=%0d -> %0d)", label, n, kf, expect);
            end
        end
    endtask

    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, testbench);

        errors = 0;
        manual14 = 14'd8192;
        note = 7'd60;
        keyfollow7 = 7'd0;
        lfo_sig = 8'd128;
        lfo_depth7 = 7'd0;
        env_u16 = 16'd0;
        env_amount7 = 7'd0;
        #1;
        expect_eq(14'd8192, "manual_only");

        // key follow off: note change must not move cutoff
        keyfollow7 = 7'd0;
        for (n = 36; n <= 84; n = n + 12) begin
            note = n[6:0];
            #1;
            expect_eq(14'd8192, "keyfollow_off_invariant");
        end

        // 100% key follow: ref note = manual only; ±octave shifts LUT delta
        expect_keyfollow(14'd8192, 7'd60, 7'd127, "keyfollow_full_ref");
        expect_keyfollow(14'd8192, 7'd72, 7'd127, "keyfollow_full_oct_up");
        expect_keyfollow(14'd8192, 7'd48, 7'd127, "keyfollow_full_oct_down");
        expect_keyfollow(14'd8192, 7'd69, 7'd127, "keyfollow_full_a4");

        // 50% key follow
        expect_keyfollow(14'd8192, 7'd72, 7'd64, "keyfollow_half_oct_up");
        expect_keyfollow(14'd8192, 7'd48, 7'd64, "keyfollow_half_oct_down");

        // monotonic: higher MIDI note -> higher effective cutoff at 100% follow
        manual14 = 14'd5000;
        keyfollow7 = 7'd127;
        lfo_sig = 8'd128;
        lfo_depth7 = 7'd0;
        monotone_ok = 1;
        prev_out = -1;
        for (n = 40; n <= 80; n = n + 1) begin
            note = n[6:0];
            #1;
            out_val = fcut14_out;
            if (prev_out >= 0 && out_val < prev_out)
                monotone_ok = 0;
            prev_out = out_val;
        end
        if (monotone_ok)
            $display("OK svf_fcut_mix keyfollow_monotone_40_80");
        else begin
            $display("FAIL svf_fcut_mix keyfollow_monotone_40_80");
            errors = errors + 1;
        end

        // LFO modulation (unchanged)
        manual14 = 14'd8192;
        note = 7'd60;
        keyfollow7 = 7'd0;
        lfo_sig = 8'd255;
        lfo_depth7 = 7'd127;
        #1;
        if (fcut14_out <= manual14) begin
            $display("FAIL svf_fcut_mix lfo_pos: got %0d expect > %0d", fcut14_out, manual14);
            errors = errors + 1;
        end else begin
            $display("OK svf_fcut_mix lfo_positive");
        end

        lfo_sig = 8'd0;
        #1;
        if (fcut14_out >= manual14) begin
            $display("FAIL svf_fcut_mix lfo_neg: got %0d expect < %0d", fcut14_out, manual14);
            errors = errors + 1;
        end else begin
            $display("OK svf_fcut_mix lfo_negative");
        end

        manual14 = 14'd100;
        keyfollow7 = 7'd0;
        lfo_sig = 8'd0;
        lfo_depth7 = 7'd127;
        #1;
        if (fcut14_out !== 14'd0) begin
            $display("FAIL svf_fcut_mix clamp_low: got %0d expect 0", fcut14_out);
            errors = errors + 1;
        end else begin
            $display("OK svf_fcut_mix clamp_low");
        end

        manual14 = 14'd16300;
        lfo_sig = 8'd255;
        lfo_depth7 = 7'd127;
        #1;
        if (fcut14_out !== 14'd16383) begin
            $display("FAIL svf_fcut_mix clamp_high: got %0d expect 16383", fcut14_out);
            errors = errors + 1;
        end else begin
            $display("OK svf_fcut_mix clamp_high");
        end

        // key follow + clamp: low manual + low note must not underflow
        expect_keyfollow(14'd200, 7'd36, 7'd127, "keyfollow_clamp_low");

        // filter env: amount=0 ignores envelope level
        manual14 = 14'd8192;
        note = 7'd60;
        keyfollow7 = 7'd0;
        lfo_sig = 8'd128;
        lfo_depth7 = 7'd0;
        env_u16 = 16'hFFFF;
        env_amount7 = 7'd0;
        #1;
        expect_eq(14'd8192, "env_amount_off");

        env_amount7 = 7'd127;
        env_u16 = 16'd128;
        #1;
        if (fcut14_out !== 14'd8319) begin
            $display("FAIL svf_fcut_mix env_additive: got %0d expect 8319", fcut14_out);
            errors = errors + 1;
        end else begin
            $display("OK svf_fcut_mix env_additive");
        end

        env_u16 = 16'hFFFF;
        manual14 = 14'd16300;
        #1;
        if (fcut14_out !== 14'd16383) begin
            $display("FAIL svf_fcut_mix env_clamp_high: got %0d expect 16383", fcut14_out);
            errors = errors + 1;
        end else begin
            $display("OK svf_fcut_mix env_clamp_high");
        end


        if (errors)
            $fatal(1, "svf_fcut_mix: %0d check(s) failed", errors);

        $display("svf_fcut_mix self-check: OK");
        $finish;
    end

endmodule
