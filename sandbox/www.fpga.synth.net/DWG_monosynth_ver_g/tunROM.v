// Scott Gravenhorst
// Tuning ROM
// address expected to be a MIDI note number
// output is the waveguide length for the MIDI note number supplied

module tun( O, A );

output [10:0] O;
input [5:0] A;

wire [10:0] O;
wire [5:0] A;

ROM64X1 # (.INIT(64'h00001DF3240088BB)) tunROM00 (.O(O[0]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00001621FF32C09A)) tunROM01 (.O(O[1]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h000012BF421F73BE)) tunROM02 (.O(O[2]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00001B3F2BF42165)) tunROM03 (.O(O[3]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00001695B3F2BF42)) tunROM04 (.O(O[4]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00000E73695B3F2B)) tunROM05 (.O(O[5]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h000001F0E73695B3)) tunROM06 (.O(O[6]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00001FF01F0E7369)) tunROM07 (.O(O[7]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000000FFF01F0E7)) tunROM08 (.O(O[8]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000000000FFF01F)) tunROM09 (.O(O[9]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000000000000FFF)) tunROM10 (.O(O[10]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));

endmodule
