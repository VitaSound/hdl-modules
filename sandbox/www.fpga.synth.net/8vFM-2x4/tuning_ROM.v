// This ROM set is generated for a sample rate of 65104.166667
// Generated by lut4tuninrom.c
//
module tuning_ROM (addr, out_hi, out_lo);
  input [3:0] addr;
  output [17:0] out_hi;
  output [17:0] out_lo;
  wire [3:0] addr;
  wire [17:0] out_hi;
  wire [17:0] out_lo;

  assign out_hi[17] = 1'b0;
  assign out_lo[17] = 1'b0;

// HIGH ROM:
  LUT4 #(.INIT(16'b0000011100001111)) tunROMhi05 ( .O(out_hi[0]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000011011111110)) tunROMhi06 ( .O(out_hi[1]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000101001001101)) tunROMhi07 ( .O(out_hi[2]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000100011111000)) tunROMhi08 ( .O(out_hi[3]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000100101101011)) tunROMhi09 ( .O(out_hi[4]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000101010000010)) tunROMhi10 ( .O(out_hi[5]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000001101101100)) tunROMhi11 ( .O(out_hi[6]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000101000110000)) tunROMhi12 ( .O(out_hi[7]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111001110011)) tunROMhi13 ( .O(out_hi[8]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111111001011)) tunROMhi14 ( .O(out_hi[9]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000101111010011)) tunROMhi15 ( .O(out_hi[10]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000100101100011)) tunROMhi16 ( .O(out_hi[11]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000100011010110)) tunROMhi17 ( .O(out_hi[12]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000110101100100)) tunROMhi18 ( .O(out_hi[13]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111001111000)) tunROMhi19 ( .O(out_hi[14]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111110000000)) tunROMhi20 ( .O(out_hi[15]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111111111111)) tunROMhi21 ( .O(out_hi[16]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );

// LOW ROM:
  LUT4 #(.INIT(16'b0000111000011110)) tunROMlo05 ( .O(out_lo[0]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000110111111101)) tunROMlo06 ( .O(out_lo[1]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000010010011011)) tunROMlo07 ( .O(out_lo[2]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000000111110001)) tunROMlo08 ( .O(out_lo[3]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000001011010111)) tunROMlo09 ( .O(out_lo[4]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000010100000100)) tunROMlo10 ( .O(out_lo[5]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000011011011001)) tunROMlo11 ( .O(out_lo[6]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000010001100001)) tunROMlo12 ( .O(out_lo[7]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000110011100111)) tunROMlo13 ( .O(out_lo[8]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111110010111)) tunROMlo14 ( .O(out_lo[9]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000011110100111)) tunROMlo15 ( .O(out_lo[10]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000001011000111)) tunROMlo16 ( .O(out_lo[11]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000000110101101)) tunROMlo17 ( .O(out_lo[12]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000101011001001)) tunROMlo18 ( .O(out_lo[13]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000110011110001)) tunROMlo19 ( .O(out_lo[14]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111100000001)) tunROMlo20 ( .O(out_lo[15]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );
  LUT4 #(.INIT(16'b0000111111111110)) tunROMlo21 ( .O(out_lo[16]), .I0(addr[0]), .I1(addr[1]), .I2(addr[2]), .I3(addr[3]) );

endmodule