`timescale 1ns / 1ps

module testbench();
  localparam CLK_HZ = 1_000_000;
  localparam integer EXP_PERIOD_NS = 1_000_000_000 / 440;
  localparam integer TOL_NS = EXP_PERIOD_NS / 20;

  localparam SUSTAIN = 3'd3;

  reg clk;
  reg rst;
  reg gate;
  reg note_on;
  reg [6:0] note;
  reg [13:0] pitch;
  reg [7:0] lfo_sig;
  reg [6:0] lfo_depth;
  reg [6:0] lfo_depth_fine;
  reg [2:0] wave_form;
  reg [31:0] attack_rate;
  reg [31:0] decay_rate;
  reg [31:0] sustain_level;
  reg [31:0] release_rate;
  wire [15:0] signal_out;
  wire        audio_valid_unused;

  integer errors;
  integer wf;
  integer measured_ns;
  integer ok;
  reg prev_hi;
  reg prev_cross;
  integer t_edges [0:2];
  integer edge_count;
  integer i;
  integer t_limit;
  integer prev_env;
  integer prev_cv;
  integer cv_unique;
  reg [7:0] cv_seen [0:255];
  integer peak_dev;
  integer dev;
  integer env_before;

  always #500 clk <= ~clk;

  mono_voice #(
    .CLK_HZ(CLK_HZ),
    .OUT_WIDTH(16),
    .SAMPLE_CLK_FREQ(48000)
  ) dut(
    .clk(clk),
    .rst(rst),
    .gate(gate),
        .note_on(note_on),
    .note(note),
    .pitch(pitch),
    .lfo_sig(lfo_sig),
    .lfo_depth(lfo_depth),
    .lfo_depth_fine(lfo_depth_fine),
    .wave_form(wave_form),
    .attack_rate(attack_rate),
    .decay_rate(decay_rate),
    .sustain_level(sustain_level),
    .release_rate(release_rate),
    .svf_f(18'sd0),
    .svf_q(18'sd0),
    .svf_mode(2'd0),
    .audio_valid(audio_valid_unused),
    .signal_out(signal_out)
  );

  task measure_period;
    input [2:0] wf_in;
    output integer period_out;
    output integer pass;
    begin
      wave_form = wf_in;
      edge_count = 0;
      pass = 1;
      period_out = 0;
      prev_cross = (signal_out >= 16'd32768);

      repeat (5000) @(posedge clk);

      t_limit = $time + 12_000_000;

      while (edge_count < 3 && $time < t_limit) begin
        @(posedge clk);
        if ((signal_out >= 16'd32768) && !prev_cross) begin
          t_edges[edge_count] = $time;
          edge_count = edge_count + 1;
        end
        prev_cross = (signal_out >= 16'd32768);
      end

      if (edge_count < 3) begin
        $display("FAIL mono_voice wf=%0d: only %0d edges", wf_in, edge_count);
        pass = 0;
      end else begin
        period_out = t_edges[2] - t_edges[1];
        if (period_out < (EXP_PERIOD_NS - TOL_NS) || period_out > (EXP_PERIOD_NS + TOL_NS)) begin
          $display("FAIL mono_voice wf=%0d: period=%0d ns expect=%0d +/-%0d",
                   wf_in, period_out, EXP_PERIOD_NS, TOL_NS);
          pass = 0;
        end else begin
          $display("OK mono_voice wf=%0d: period=%0d ns", wf_in, period_out);
        end
      end
    end
  endtask

  task voice_reset;
    begin
      gate = 0;
      rst = 1;
      repeat (4) @(posedge clk);
      rst = 0;
      @(posedge clk);
    end
  endtask

  task wait_env_state;
    input [2:0] target;
    input integer max_clocks;
    integer n;
    begin
      for (n = 0; n < max_clocks; n = n + 1) begin
        @(posedge clk);
        if (dut.env.state == target)
          disable wait_env_state;
      end
      $display("FAIL mono_voice: env state %0d not reached in %0d clocks (now %0d)",
               target, max_clocks, dut.env.state);
      errors = errors + 1;
    end
  endtask

  task check_attack_audio_grows;
    begin
      voice_reset();
      wave_form = 3'd1;
      attack_rate  = 32'd800_000;
      decay_rate   = 32'd800_000;
      sustain_level = {7'd127, 25'b0};
      release_rate = 32'd500_000;
      gate = 1;
      note = 7'd69;

      repeat (100) @(posedge clk);

      peak_dev = 0;
      for (i = 0; i < 250_000; i = i + 1) begin
        @(posedge clk);
        dev = (signal_out >= 16'd32768)
            ? (signal_out - 16'd32768)
            : (16'd32768 - signal_out);
        if (dev > peak_dev)
          peak_dev = dev;
      end

      if (peak_dev < 16'd2000) begin
        $display("FAIL mono_voice attack_audio: peak deviation %0d too small", peak_dev);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice attack_audio_grows (peak dev=%0d)", peak_dev);
      end
    end
  endtask

  task check_env_reaches_sustain;
    reg [31:0] sustain;
    begin
      voice_reset();
      sustain = {7'd96, 25'b0};
      attack_rate  = 32'd1_000_000;
      decay_rate   = 32'd500_000;
      sustain_level = sustain;
      release_rate = 32'd500_000;
      gate = 1;

      wait_env_state(SUSTAIN, 3_000_000);

      if (dut.env.signal_out != sustain) begin
        $display("FAIL mono_voice sustain_env: got %0h expect %0h",
                 dut.env.signal_out, sustain);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice env_reaches_sustain");
      end
    end
  endtask

  task check_legato_note_change;
    begin
      voice_reset();
      attack_rate  = 32'd1_000_000;
      decay_rate   = 32'd500_000;
      sustain_level = {7'd96, 25'b0};
      release_rate = 32'd500_000;
      gate = 1;
      note = 7'd60;
      wait_env_state(SUSTAIN, 3_000_000);
      env_before = dut.env.signal_out;

      note = 7'd72;
      repeat (5000) @(posedge clk);

      if (dut.env.signal_out != env_before) begin
        $display("FAIL mono_voice legato: env changed %0h -> %0h",
                 env_before, dut.env.signal_out);
        errors = errors + 1;
      end else if (dut.env.state != SUSTAIN) begin
        $display("FAIL mono_voice legato: state %0d", dut.env.state);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice legato_note_change");
      end
    end
  endtask

  task check_staccato_retrigger;
    begin
      voice_reset();
      attack_rate  = 32'd1_000_000;
      decay_rate   = 32'd500_000;
      sustain_level = {7'd96, 25'b0};
      release_rate = 32'd800_000;
      gate = 1;
      wait_env_state(SUSTAIN, 3_000_000);

      gate = 0;
      repeat (500_000) @(posedge clk);

      if (dut.env.signal_out != 32'd0) begin
        $display("FAIL mono_voice staccato: env not zero after release %0h",
                 dut.env.signal_out);
        errors = errors + 1;
        disable check_staccato_retrigger;
      end

      gate = 1;
      wait_env_state(3'd1, 500_000);

      if (dut.env.state != 3'd1) begin
        $display("FAIL mono_voice staccato: expected ATTACK, state=%0d", dut.env.state);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice staccato_retrigger");
      end
    end
  endtask

  task check_cv8_decay_steps;
    input [6:0] sustain7;
    input integer min_steps;
    input integer max_steps;
    input integer tag;
    reg [31:0] sustain;
    integer cv;
    begin
      voice_reset();
      sustain = {sustain7, 25'b0};
      attack_rate  = 32'd1_500_000;
      decay_rate   = 32'd800_000;
      sustain_level = sustain;
      release_rate = 32'd500_000;
      gate = 1;

      wait_env_state(3'd2, 3_000_000);

      for (i = 0; i < 256; i = i + 1)
        cv_seen[i] = 0;
      cv_unique = 0;

      while (dut.env.state == 3'd2) begin
        @(posedge clk);
        cv = dut.env.signal_out[31:24];
        if (!cv_seen[cv]) begin
          cv_seen[cv] = 1;
          cv_unique = cv_unique + 1;
        end
      end

      if (dut.env.signal_out != sustain) begin
        $display("FAIL mono_voice cv8_decay tag=%0d: env %0h != sustain %0h",
                 tag, dut.env.signal_out, sustain);
        errors = errors + 1;
      end else if (cv_unique < min_steps || cv_unique > max_steps) begin
        $display("FAIL mono_voice cv8_decay tag=%0d: steps=%0d expect %0d..%0d",
                 tag, cv_unique, min_steps, max_steps);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice cv8_decay tag=%0d (%0d cv8 steps)", tag, cv_unique);
      end
    end
  endtask

  task check_fast_staccato;
    integer env_start;
    begin
      voice_reset();
      note_on = 0;
      attack_rate  = 32'hFFFF_FFFF;
      decay_rate   = 32'hFFFF_FFFF;
      sustain_level = {7'd127, 25'b0};
      release_rate = 32'hFFFF_FFFF;
      gate = 1;
      note = 7'd69;
      wait_env_state(SUSTAIN, 3_000_000);

      gate = 0;
      repeat (5) @(posedge clk);
      gate = 1;
      note_on = 1;
      @(posedge clk);
      #0;
      note_on = 0;

      wait_env_state(3'd1, 500_000);
      env_start = dut.env.signal_out;

      if (dut.env.state != 3'd1) begin
        $display("FAIL mono_voice fast_staccato: state=%0d", dut.env.state);
        errors = errors + 1;
      end else if (env_start > 32'h00FF_FFFF) begin
        $display("FAIL mono_voice fast_staccato: env not reset %0h", env_start);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice fast_staccato");
      end
    end
  endtask

  task check_release_silence;
    begin
      voice_reset();
      attack_rate  = 32'd1_000_000;
      decay_rate   = 32'd500_000;
      sustain_level = {7'd96, 25'b0};
      release_rate = 32'd800_000;
      gate = 1;
      wait_env_state(SUSTAIN, 3_000_000);

      release_rate = 32'd800_000;
      gate = 0;
      repeat (400_000) @(posedge clk);

      if ((signal_out > 16'd33000) || (signal_out < 16'd32500)) begin
        $display("FAIL mono_voice release: signal_out=%0d expect ~32768", signal_out);
        errors = errors + 1;
      end else begin
        $display("OK mono_voice release_silence");
      end
    end
  endtask

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);

    clk = 0;
    rst = 1;
    gate = 0;
    note_on = 0;
    note = 7'd69;
    pitch = 14'd8192;
    lfo_sig = 8'd128;
    lfo_depth = 7'd0;
    lfo_depth_fine = 7'd0;
    wave_form = 3'd1;
    attack_rate = 32'd20000;
    decay_rate = 32'd20000;
    sustain_level = {7'd127, 25'b0};
    release_rate = 32'd500000;
    errors = 0;

    repeat (4) @(posedge clk);
    rst = 0;
    gate = 1;
    repeat (15000) @(posedge clk);

    for (wf = 0; wf <= 5; wf = wf + 1) begin
      measure_period(wf[2:0], measured_ns, ok);
      if (!ok)
        errors = errors + 1;
    end

    check_attack_audio_grows();
    check_env_reaches_sustain();
    check_legato_note_change();
    check_cv8_decay_steps(7'd127, 2, 4, 127);
    check_cv8_decay_steps(7'd64, 32, 200, 64);
    check_staccato_retrigger();
    check_fast_staccato();
    check_release_silence();

    if (errors)
      $fatal(1, "mono_voice: %0d check(s) failed", errors);

    $display("mono_voice self-check: OK (pitch + envelope)");
    $finish;
  end
endmodule
