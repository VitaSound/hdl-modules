// MIDI byte parser (channel voice + SysEx skip). Byte stream in; no UART.
// FSM from fpga-synth/modules/midi_in.v; UART removed; SysEx discard added.
module midi_in #(
    parameter SYSEX_MODE = 0
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       byte_valid,
    input  wire [7:0] byte_in,
    output wire       midi_command_ready,
    output wire [3:0] ch_message,
    output wire [3:0] chan,
    output wire [6:0] note,
    output wire [6:0] lsb,
    output wire [6:0] msb,
    output wire       sysex_byte_valid,
    output wire [7:0] sysex_byte,
    output wire       sysex_done,
    output wire       sysex_overflow
);

    localparam [7:0] ST_IDLE      = 8'd0;
    localparam [7:0] ST_WAIT_D1   = 8'd1;
    localparam [7:0] ST_WAIT_D2   = 8'd2;
    localparam [7:0] ST_SYSEX     = 8'd3;

    reg [7:0] rcv_state;
    reg [7:0] byte1;
    reg [7:0] byte2;
    reg [7:0] byte3;
    reg       midi_command_ready_r;

    initial begin
        rcv_state            = ST_IDLE;
        byte1                = 8'd0;
        byte2                = 8'd0;
        byte3                = 8'd0;
        midi_command_ready_r = 1'b0;
    end

    wire channel_status = (byte_in[7:4] >= 4'h8) && (byte_in[7:4] <= 4'hE);

    reg sysex_byte_valid_r;
    reg [7:0] sysex_byte_r;
    reg sysex_done_r;
    reg sysex_overflow_r;

    initial begin
        sysex_byte_valid_r = 1'b0;
        sysex_byte_r       = 8'd0;
        sysex_done_r       = 1'b0;
        sysex_overflow_r   = 1'b0;
    end

    always @(posedge clk) begin
        midi_command_ready_r <= 1'b0;
        sysex_byte_valid_r   <= 1'b0;
        sysex_done_r         <= 1'b0;
        sysex_overflow_r     <= 1'b0;

        if (rst) begin
            rcv_state <= ST_IDLE;
            byte1     <= 8'd0;
            byte2     <= 8'd0;
            byte3     <= 8'd0;
        end else if (byte_valid) begin
            case (rcv_state)
                ST_IDLE: begin
                    if (byte_in == 8'hF0) begin
                        rcv_state <= ST_SYSEX;
                        if (SYSEX_MODE) begin
                            sysex_byte_valid_r <= 1'b1;
                            sysex_byte_r       <= byte_in;
                        end
                    end else if (channel_status && byte_in[7]) begin
                        byte1     <= byte_in;
                        rcv_state <= ST_WAIT_D1;
                    end
                end

                ST_WAIT_D1: begin
                    if (!byte_in[7]) begin
                        byte2     <= byte_in;
                        rcv_state <= ST_WAIT_D2;
                    end else begin
                        rcv_state <= ST_IDLE;
                    end
                end

                ST_WAIT_D2: begin
                    if (!byte_in[7]) begin
                        byte3                <= byte_in;
                        midi_command_ready_r <= 1'b1;
                        rcv_state            <= ST_IDLE;
                    end else begin
                        rcv_state <= ST_IDLE;
                    end
                end

                ST_SYSEX: begin
                    if (byte_in == 8'hF7) begin
                        rcv_state    <= ST_IDLE;
                        sysex_done_r <= SYSEX_MODE;
                    end else if (SYSEX_MODE) begin
                        sysex_byte_valid_r <= 1'b1;
                        sysex_byte_r       <= byte_in;
                    end
                end

                default: rcv_state <= ST_IDLE;
            endcase
        end
    end

    assign midi_command_ready = midi_command_ready_r;
    assign chan               = midi_command_ready_r ? byte1[3:0] : 4'b0000;
    assign ch_message         = midi_command_ready_r ? byte1[7:4] : 4'b0000;

    wire pccp = (byte1[7:4] == 4'hC) || (byte1[7:4] == 4'hD);
    assign lsb = midi_command_ready_r ? byte2[6:0] : 7'd0;
    assign msb = (midi_command_ready_r && !pccp) ? byte3[6:0] : 7'd0;

    wire note_info = (byte1[7:4] == 4'h8) || (byte1[7:4] == 4'h9) || (byte1[7:4] == 4'hA);
    assign note = (midi_command_ready_r && note_info) ? byte2[6:0] : 7'd0;

    assign sysex_byte_valid = sysex_byte_valid_r;
    assign sysex_byte       = sysex_byte_r;
    assign sysex_done       = sysex_done_r;
    assign sysex_overflow   = sysex_overflow_r;

endmodule
