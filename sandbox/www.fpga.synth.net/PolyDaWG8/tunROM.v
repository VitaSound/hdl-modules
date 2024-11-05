// Scott Gravenhorst
// email: music.maker@gte.net
// Tuning ROM
// address expected to be a MIDI note number
// output is the waveguide length for the MIDI note number supplied

module tun( O, A );

output [10:0] O;
input [5:0] A;

wire [10:0] O;
wire [5:0] A;

// This ROM data starts with the longest waveguide length set to 2047, the maximum length.
ROM64X1 # (.INIT(64'h00001DACA21A976D)) tunROM00 (.O(O[0]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000098D7ACA30C5)) tunROM01 (.O(O[1]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h000004CCB8D7BCE7)) tunROM02 (.O(O[2]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000290C6CCB9D3F)) tunROM03 (.O(O[3]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h000024A6B0C6DCBD)) tunROM04 (.O(O[4]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00001C626A6B1C69)) tunROM05 (.O(O[5]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h000003E1E626B6B1)) tunROM06 (.O(O[6]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h00003FE01E1E726B)) tunROM07 (.O(O[7]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000001FFE01F1E7)) tunROM08 (.O(O[8]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000000001FFF01F)) tunROM09 (.O(O[9]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));
ROM64X1 # (.INIT(64'h0000000000000FFF)) tunROM10 (.O(O[10]),.A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]));

endmodule

