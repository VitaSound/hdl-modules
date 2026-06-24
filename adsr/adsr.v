// ADSR FSM; envelope advances on tick. note_on latches note_on between ticks.
module adsr #(
    parameter ACCUM_BITS = 32,
    parameter RATE_BITS  = 32,
    parameter CV_BITS    = 16
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   tick,
    input  wire                   gate,
    input  wire                   note_on,
    input  wire [RATE_BITS - 1:0] attack_rate,
    input  wire [RATE_BITS - 1:0] decay_rate,
    input  wire [RATE_BITS - 1:0] sustain_level,
    input  wire [RATE_BITS - 1:0] release_rate,
    output wire [ACCUM_BITS - 1:0] signal_out
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] ATTACK  = 3'd1;
    localparam [2:0] DECAY   = 3'd2;
    localparam [2:0] SUSTAIN = 3'd3;
    localparam [2:0] RELEASE = 3'd4;

    reg [2:0] state;
    reg [ACCUM_BITS - 1:0] sout;

    reg gate_d;
    reg gate_fell;
    reg note_on_lat;

    initial begin
        state = IDLE;
        sout  = {ACCUM_BITS{1'b0}};
    end

    wire [ACCUM_BITS:0] sum_attack = {1'b0, sout} + {{(ACCUM_BITS - RATE_BITS){1'b0}}, attack_rate};
    wire attack_overflow = sum_attack > {1'b0, {ACCUM_BITS{1'b1}}};
    wire [ACCUM_BITS - 1:0] next_attack = attack_overflow ? {ACCUM_BITS{1'b1}} : sum_attack[ACCUM_BITS - 1:0];

    wire [ACCUM_BITS - 1:0] next_decay =
        (sout > decay_rate) && ((sout - decay_rate) > sustain_level)
            ? (sout - decay_rate)
            : sustain_level;

    wire [ACCUM_BITS - 1:0] next_release =
        (sout > release_rate) ? (sout - release_rate) : {ACCUM_BITS{1'b0}};

    always @(posedge clk) begin
        if (rst) begin
            gate_d      <= 1'b0;
            gate_fell   <= 1'b0;
            note_on_lat <= 1'b0;
        end else begin
            gate_d <= gate;
            if (!gate && gate_d)
                gate_fell <= 1'b1;
            if (note_on)
                note_on_lat <= 1'b1;
        end
    end

    wire gate_release = !gate || (gate_fell && !gate);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            sout  <= {ACCUM_BITS{1'b0}};
        end else if (tick) begin
            if (note_on_lat || note_on) begin
                sout          <= {ACCUM_BITS{1'b0}};
                state         <= ATTACK;
                note_on_lat   <= 1'b0;
                gate_fell     <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        gate_fell <= 1'b0;
                        if (gate)
                            state <= ATTACK;
                    end

                    ATTACK: begin
                        if (gate_release) begin
                            state <= RELEASE;
                            gate_fell <= 1'b0;
                        end else begin
                            sout <= next_attack;
                            if (attack_overflow)
                                state <= DECAY;
                        end
                    end

                    DECAY: begin
                        if (gate_release) begin
                            state <= RELEASE;
                            gate_fell <= 1'b0;
                        end else begin
                            sout <= next_decay;
                            if (sout == sustain_level || next_decay == sustain_level)
                                state <= SUSTAIN;
                        end
                    end

                    SUSTAIN: begin
                        gate_fell <= 1'b0;
                        if (gate_release)
                            state <= RELEASE;
                    end

                    RELEASE: begin
                        if (gate && !gate_release) begin
                            sout  <= {ACCUM_BITS{1'b0}};
                            state <= ATTACK;
                            gate_fell <= 1'b0;
                        end else begin
                            sout <= next_release;
                            if (next_release == {ACCUM_BITS{1'b0}})
                                state <= IDLE;
                        end
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

    assign signal_out = sout;

endmodule
