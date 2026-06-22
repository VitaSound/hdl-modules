// Legacy adsr32 FSM; envelope advances on tick (audio-rate strobe, not system clk).
module adsr #(
    parameter ACCUM_BITS = 32,
    parameter RATE_BITS  = 32,
    parameter CV_BITS    = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   tick,
    input  wire                   gate,
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
            state <= IDLE;
            sout  <= {ACCUM_BITS{1'b0}};
        end else if (tick) begin
            case (state)
                IDLE: begin
                    if (gate)
                        state <= ATTACK;
                end

                ATTACK: begin
                    if (!gate) begin
                        state <= RELEASE;
                    end else begin
                        sout <= next_attack;
                        if (attack_overflow)
                            state <= DECAY;
                    end
                end

                DECAY: begin
                    if (!gate) begin
                        state <= RELEASE;
                    end else begin
                        sout <= next_decay;
                        if (sout == sustain_level || next_decay == sustain_level)
                            state <= SUSTAIN;
                    end
                end

                SUSTAIN: begin
                    if (!gate)
                        state <= RELEASE;
                end

                RELEASE: begin
                    if (gate) begin
                        sout  <= {ACCUM_BITS{1'b0}};
                        state <= ATTACK;
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

    assign signal_out = sout;

endmodule
