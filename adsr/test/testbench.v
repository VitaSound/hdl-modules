`timescale 1ns / 1ps

module testbench();
    localparam IDLE    = 3'd0;
    localparam ATTACK  = 3'd1;
    localparam DECAY   = 3'd2;
    localparam SUSTAIN = 3'd3;
    localparam RELEASE = 3'd4;

    localparam MAX_ENV = 32'hFFFF_FFFF;

    reg clk;
    reg rst;
    reg tick;
    reg gate;
    reg note_on;
    reg sound_off;
    reg [31:0] attack_rate;
    reg [31:0] decay_rate;
    reg [31:0] sustain_level;
    reg [31:0] release_rate;

    wire [31:0] signal_out;

    integer errors;
    integer i;
    integer prev;
    integer cv_unique;
    reg [7:0] cv_seen [0:255];

    initial clk <= 0;
    always #10 clk <= ~clk;

    adsr env(
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .gate(gate),
        .note_on(note_on),
        .sound_off(sound_off),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .signal_out(signal_out)
    );

    task pulse_tick;
        begin
            @(posedge clk);
            tick <= 1'b1;
            @(posedge clk);
            tick <= 1'b0;
        end
    endtask

    task run_ticks;
        input integer count;
        input gate_val;
        integer n;
        begin
            gate = gate_val;
            for (n = 0; n < count; n = n + 1)
                pulse_tick();
        end
    endtask

    task env_reset;
        begin
            gate = 0;
            note_on = 0;
            sound_off = 0;
            tick = 0;
            rst = 1;
            repeat (2) @(posedge clk);
            rst = 0;
            @(posedge clk);
        end
    endtask

    task wait_state;
        input [2:0] target;
        input integer max_ticks;
        integer n;
        begin
            for (n = 0; n < max_ticks; n = n + 1) begin
                pulse_tick();
                if (env.state == target)
                    disable wait_state;
            end
            $display("FAIL adsr: state %0d not reached in %0d ticks (now %0d)",
                     target, max_ticks, env.state);
            errors = errors + 1;
        end
    endtask

    task check_attack_rises;
        begin
            env_reset();
            attack_rate  = 32'd100_000;
            decay_rate   = 32'd100_000;
            sustain_level = {7'd64, 25'b0};
            release_rate = 32'd80_000;

            gate = 1;
            prev = 0;
            for (i = 0; i < 200; i = i + 1) begin
                pulse_tick();
                if (signal_out < prev) begin
                    $display("FAIL adsr attack: not monotonic at tick %0d (%0d -> %0d)",
                             i, prev, signal_out);
                    errors = errors + 1;
                    disable check_attack_rises;
                end
                prev = signal_out;
            end

            if (signal_out == 32'd0) begin
                $display("FAIL adsr attack: still zero after 200 ticks");
                errors = errors + 1;
            end else begin
                $display("OK adsr attack_rises");
            end
        end
    endtask

    task check_decay_monotonic;
        reg [31:0] sustain;
        begin
            env_reset();
            sustain = {7'd80, 25'b0};
            attack_rate  = 32'd400_000;
            decay_rate   = 32'd100_000;
            sustain_level = sustain;
            release_rate = 32'd80_000;

            gate = 1;
            wait_state(DECAY, 300_000);

            prev = MAX_ENV;
            while (env.state == DECAY) begin
                pulse_tick();
                if (signal_out > prev) begin
                    $display("FAIL adsr decay: increased %0d -> %0d", prev, signal_out);
                    errors = errors + 1;
                    disable check_decay_monotonic;
                end
                prev = signal_out;
            end
            $display("OK adsr decay_monotonic");
        end
    endtask

    task check_decay_to_sustain;
        reg [31:0] sustain;
        begin
            env_reset();
            sustain = {7'd64, 25'b0};
            attack_rate  = 32'd300_000;
            decay_rate   = 32'd120_000;
            sustain_level = sustain;
            release_rate = 32'd80_000;

            gate = 1;
            wait_state(SUSTAIN, 300_000);

            if (signal_out != sustain) begin
                $display("FAIL adsr decay: sustain level %0h got %0h", sustain, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr decay_to_sustain");
            end
        end
    endtask

    task check_sustain_holds;
        reg [31:0] held;
        begin
            env_reset();
            sustain_level = {7'd96, 25'b0};
            attack_rate  = 32'd400_000;
            decay_rate   = 32'd100_000;
            release_rate = 32'd80_000;
            gate = 1;
            wait_state(SUSTAIN, 300_000);

            held = signal_out;
            run_ticks(500, 1);

            if (env.state != SUSTAIN) begin
                $display("FAIL adsr sustain: left state, now %0d", env.state);
                errors = errors + 1;
            end else if (signal_out != held) begin
                $display("FAIL adsr sustain: value changed %0h -> %0h", held, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr sustain_holds");
            end
        end
    endtask

    task check_release_to_idle;
        begin
            env_reset();
            sustain_level = {7'd96, 25'b0};
            attack_rate  = 32'd400_000;
            decay_rate   = 32'd100_000;
            release_rate = 32'd150_000;
            gate = 1;
            wait_state(SUSTAIN, 300_000);

            gate = 0;
            prev = signal_out;

            for (i = 0; i < 200_000; i = i + 1) begin
                pulse_tick();
                if (signal_out > prev) begin
                    $display("FAIL adsr release: increased at tick %0d", i);
                    errors = errors + 1;
                    disable check_release_to_idle;
                end
                prev = signal_out;
                if (env.state == IDLE && signal_out == 32'd0)
                    disable check_release_to_idle;
            end

            if (env.state != IDLE || signal_out != 32'd0) begin
                $display("FAIL adsr release: not idle/zero, state=%0d out=%0h",
                         env.state, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr release_to_idle");
            end
        end
    endtask

    task check_gate_off_in_attack;
        begin
            env_reset();
            attack_rate  = 32'd50_000;
            decay_rate   = 32'd50_000;
            sustain_level = {7'd32, 25'b0};
            release_rate = 32'd100_000;

            gate = 1;
            run_ticks(50, 1);

            if (env.state != ATTACK) begin
                $display("FAIL adsr gate_off_attack: expected ATTACK, got %0d", env.state);
                errors = errors + 1;
                disable check_gate_off_in_attack;
            end

            if (signal_out == 32'd0) begin
                $display("FAIL adsr gate_off_attack: no progress in attack");
                errors = errors + 1;
                disable check_gate_off_in_attack;
            end

            gate = 0;
            run_ticks(2, 0);

            if (env.state != RELEASE) begin
                $display("FAIL adsr gate_off_attack: expected RELEASE, got %0d", env.state);
                errors = errors + 1;
            end else begin
                $display("OK adsr gate_off_in_attack");
            end

            run_ticks(200_000, 0);
            if (signal_out != 32'd0) begin
                $display("FAIL adsr gate_off_attack: release incomplete, got=%0h", signal_out);
                errors = errors + 1;
            end
        end
    endtask

    task check_retrigger_resets;
        begin
            env_reset();
            attack_rate  = 32'd300_000;
            decay_rate   = 32'd120_000;
            sustain_level = {7'd127, 25'b0};
            release_rate = 32'd100_000;

            gate = 1;
            wait_state(SUSTAIN, 300_000);
            gate = 0;
            run_ticks(2, 0);

            if (env.state != RELEASE) begin
                $display("FAIL adsr retrigger: expected RELEASE, got %0d", env.state);
                errors = errors + 1;
                disable check_retrigger_resets;
            end

            gate = 1;
            run_ticks(2, 1);

            if (env.state != ATTACK || signal_out == 32'd0) begin
                $display("FAIL adsr retrigger: expected ATTACK with held env, state=%0d out=%0h",
                         env.state, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr retrigger_resets");
            end
        end
    endtask

    task check_cv8_high_sustain_quantized;
        reg [31:0] sustain;
        integer cv;
        begin
            env_reset();
            sustain = {7'd127, 25'b0};
            attack_rate  = 32'd400_000;
            decay_rate   = 32'd400_000;
            sustain_level = sustain;
            release_rate = 32'd100_000;

            gate = 1;
            wait_state(DECAY, 400_000);

            for (i = 0; i < 256; i = i + 1)
                cv_seen[i] = 0;

            cv_unique = 0;
            while (env.state == DECAY) begin
                pulse_tick();
                cv = signal_out[31:24];
                if (!cv_seen[cv]) begin
                    cv_seen[cv] = 1;
                    cv_unique = cv_unique + 1;
                end
            end

            if (signal_out != sustain) begin
                $display("FAIL adsr cv8_high_sustain: env=%0h sustain=%0h",
                         signal_out, sustain);
                errors = errors + 1;
            end else if (cv_unique > 4) begin
                $display("FAIL adsr cv8_high_sustain: expected <=4 cv8 steps, got %0d",
                         cv_unique);
                errors = errors + 1;
            end else begin
                $display("OK adsr cv8_high_sustain (%0d cv8 steps during decay)", cv_unique);
            end
        end
    endtask

    task check_trigger_staccato;
        begin
            env_reset();
            attack_rate  = 32'd800_000;
            decay_rate   = 32'd800_000;
            sustain_level = {7'd127, 25'b0};
            release_rate = 32'd800_000;

            gate = 1;
            wait_state(SUSTAIN, 500_000);

            tick = 1'b0;
            repeat (2) @(posedge clk);
            note_on = 1;
            @(posedge clk);
            #0;
            note_on = 0;
            wait_state(ATTACK, 100);

            if (env.state != ATTACK || signal_out == 32'd0) begin
                $display("FAIL adsr trigger_staccato: state=%0d out=%0h",
                         env.state, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr trigger_staccato");
            end
        end
    endtask

    task check_min_rate_attack;
        begin
            env_reset();
            attack_rate  = 32'hFFFF_FFFF;
            decay_rate   = 32'd100_000;
            sustain_level = {7'd64, 25'b0};
            release_rate = 32'd100_000;

            gate = 1;
            wait_state(DECAY, 200);

            if (env.state != DECAY && env.state != SUSTAIN) begin
                $display("FAIL adsr min_rate_attack: state=%0d", env.state);
                errors = errors + 1;
            end else begin
                $display("OK adsr min_rate_attack (fast attack)");
            end
        end
    endtask

    task check_sound_off_panic;
        integer held;
        begin
            env_reset();
            sustain_level = {7'd96, 25'b0};
            attack_rate  = 32'd400_000;
            decay_rate   = 32'd100_000;
            release_rate = 32'd1;

            gate = 1;
            wait_state(SUSTAIN, 300_000);

            if (env.state != SUSTAIN) begin
                $display("FAIL adsr sound_off: expected SUSTAIN, got %0d", env.state);
                errors = errors + 1;
                disable check_sound_off_panic;
            end

            held = signal_out;
            if (held == 0) begin
                $display("FAIL adsr sound_off: sustain env zero before sound_off");
                errors = errors + 1;
                disable check_sound_off_panic;
            end

            tick = 0;
            @(negedge clk);
            sound_off = 1;
            @(posedge clk);
            #1;
            sound_off = 0;

            if (env.state != IDLE || signal_out != 32'd0) begin
                $display("FAIL adsr sound_off: state=%0d out=%0h expect IDLE/0",
                         env.state, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr sound_off_panic");
            end

            gate = 1;
            note_on = 1;
            pulse_tick();
            note_on = 0;
            #1;

            if (env.state != ATTACK) begin
                $display("FAIL adsr sound_off: retrigger after panic state=%0d out=%0h",
                         env.state, signal_out);
                errors = errors + 1;
            end else begin
                $display("OK adsr sound_off_retrigger");
            end
        end
    endtask

    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, testbench);

        errors = 0;
        rst = 1;
        tick = 0;
        gate = 0;
        note_on = 0;
        sound_off = 0;
        attack_rate = 32'd10000;
        decay_rate = 32'd10000;
        sustain_level = {7'd64, 25'b0};
        release_rate = 32'd8000;

        repeat (4) @(posedge clk);
        rst = 0;

        check_attack_rises();
        check_decay_monotonic();
        check_decay_to_sustain();
        check_sustain_holds();
        check_release_to_idle();
        check_gate_off_in_attack();
        check_retrigger_resets();
        check_trigger_staccato();
        check_min_rate_attack();
        check_cv8_high_sustain_quantized();
        check_sound_off_panic();

        if (errors)
            $fatal(1, "adsr: %0d check(s) failed", errors);

        $display("adsr self-check: OK (all phases)");
        $finish;
    end
endmodule
