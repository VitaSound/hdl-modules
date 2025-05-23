/*
 0: 2^-1.0000 = 0.5000000000000000
 1: 2^-0.8750 = 0.5452538663326288
 2: 2^-0.7500 = 0.5946035575013605
 3: 2^-0.6250 = 0.6484197773255048
 4: 2^-0.5000 = 0.7071067811865476
 5: 2^-0.3750 = 0.7711054127039704
 6: 2^-0.2500 = 0.8408964152537145
 7: 2^-0.1250 = 0.9170040432046712
 8: 2^+0.0000 = 1.0000000000000000
 9: 2^+0.1250 = 1.0905077326652577
10: 2^+0.2500 = 1.1892071150027210
11: 2^+0.3750 = 1.2968395546510096
12: 2^+0.5000 = 1.4142135623730951
13: 2^+0.6250 = 1.5422108254079407
14: 2^+0.7500 = 1.6817928305074290
15: 2^+0.8750 = 1.8340080864093424
-----------------
 0: 2^-0.8750 = 0.5452538663326288
 1: 2^-0.7500 = 0.5946035575013605
 2: 2^-0.6250 = 0.6484197773255048
 3: 2^-0.5000 = 0.7071067811865476
 4: 2^-0.3750 = 0.7711054127039704
 5: 2^-0.2500 = 0.8408964152537145
 6: 2^-0.1250 = 0.9170040432046712
 7: 2^+0.0000 = 1.0000000000000000
 8: 2^+0.1250 = 1.0905077326652577
 9: 2^+0.2500 = 1.1892071150027210
10: 2^+0.3750 = 1.2968395546510096
11: 2^+0.5000 = 1.4142135623730951
12: 2^+0.6250 = 1.5422108254079407
13: 2^+0.7500 = 1.6817928305074290
14: 2^+0.8750 = 1.8340080864093424
15: 2^+1.0000 = 2.0000000000000000
*/


module PW_ROM (ad, out_hi, out_lo);   // ad is the LUT address input
  input [3:0] ad;
  output [16:0] out_hi;
  output [16:0] out_lo;
  wire [3:0] ad;
  wire [16:0] out_hi;
  wire [16:0] out_lo;

  LUT4 #(.INIT(16'b0001001100010110)) LUT4pwROMhi00 ( .O(out_hi[0]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0001011000111111)) LUT4pwROMhi01 ( .O(out_hi[1]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0011111100000100)) LUT4pwROMhi02 ( .O(out_hi[2]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0000010000000111)) LUT4pwROMhi03 ( .O(out_hi[3]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0000011100010110)) LUT4pwROMhi04 ( .O(out_hi[4]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0001011001110100)) LUT4pwROMhi05 ( .O(out_hi[5]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0111010001000101)) LUT4pwROMhi06 ( .O(out_hi[6]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0100010100111101)) LUT4pwROMhi07 ( .O(out_hi[7]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0011110101100001)) LUT4pwROMhi08 ( .O(out_hi[8]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0110000100111100)) LUT4pwROMhi09 ( .O(out_hi[9]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0011110001000011)) LUT4pwROMhi10 ( .O(out_hi[10]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0100001100101010)) LUT4pwROMhi11 ( .O(out_hi[11]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0010101001001100)) LUT4pwROMhi12 ( .O(out_hi[12]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0100110001110000)) LUT4pwROMhi13 ( .O(out_hi[13]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0111000001111111)) LUT4pwROMhi14 ( .O(out_hi[14]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0111111110000000)) LUT4pwROMhi15 ( .O(out_hi[15]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1000000000000000)) LUT4pwROMhi16 ( .O(out_hi[16]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );

  LUT4 #(.INIT(16'b0010011000101100)) LUT4pwROMlo00 ( .O(out_lo[0]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0010110001111110)) LUT4pwROMlo01 ( .O(out_lo[1]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0111111000001000)) LUT4pwROMlo02 ( .O(out_lo[2]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0000100000001110)) LUT4pwROMlo03 ( .O(out_lo[3]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0000111000101100)) LUT4pwROMlo04 ( .O(out_lo[4]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0010110011101000)) LUT4pwROMlo05 ( .O(out_lo[5]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1110100010001010)) LUT4pwROMlo06 ( .O(out_lo[6]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1000101001111010)) LUT4pwROMlo07 ( .O(out_lo[7]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0111101011000010)) LUT4pwROMlo08 ( .O(out_lo[8]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1100001001111000)) LUT4pwROMlo09 ( .O(out_lo[9]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0111100010000110)) LUT4pwROMlo10 ( .O(out_lo[10]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1000011001010100)) LUT4pwROMlo11 ( .O(out_lo[11]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0101010010011000)) LUT4pwROMlo12 ( .O(out_lo[12]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1001100011100000)) LUT4pwROMlo13 ( .O(out_lo[13]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1110000011111111)) LUT4pwROMlo14 ( .O(out_lo[14]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b1111111100000000)) LUT4pwROMlo15 ( .O(out_lo[15]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
  LUT4 #(.INIT(16'b0000000000000000)) LUT4pwROMlo16 ( .O(out_lo[16]), .I0(ad[0]), .I1(ad[1]), .I2(ad[2]), .I3(ad[3]) );
endmodule
