`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Scott R. Gravenhorst
// email: music.maker@gte.net
// Create Date:    09/10/2007
// Design Name:    SVF
// Module Name:    SVF
// Project Name:   State Variable Filter
// Description:    SVF with shared multiplier.
// 
// maximum Q = 23.464375  (q = 18'sb000001010111010010)
// maximum input amplitude = +/- 2047 (12 bits)
// Execution time = 4 clocks
//
//////////////////////////////////////////////////////////////////////////////////

module SVF( 
  clk,                          // system clock
  ena,                          // Tell the filter to go
  f,                            // f (not Hz, but usable to control frequency)
  q,                            // q (1/Q)
  In,
  Out
  );

  input clk;  
  input ena;
  input signed  [17:0] f;
  input signed  [17:0] q;
  input signed  [11:0] In;
  output signed [17:0] Out;

  wire clk;
  wire ena;
  wire signed [17:0] f;
  wire signed [17:0] q;
  wire signed [11:0] In;     // 12 bit data input
  reg signed [11:0] InReg;
  wire signed [17:0] In18;   // input sign extended to 18 bits from 12 bits
  wire signed [17:0] Out;
  
  reg signed [35:0] z1 = 36'sd0;                // feedback #1
  reg signed [35:0] z2 = 36'sd0;                // feedback #2

  reg signed [17:0] mA = 18'sd0;
  reg signed [17:0] mB = 18'sd0;
  wire signed [35:0] mP;

  assign In18 = {{6{InReg[11]}},InReg};    // sign extension

  assign Out = z2 >>> 18;

  assign mP = mA * mB;

// SVF state machine, shares a multiplier
  reg run = 1'b0;
  reg [2:0] state = 3'b0;

  always @ ( posedge clk )
    begin
    if ( ena == 1'b1 ) 
      begin
      run <= 1'b1;
      state <= 3'd0;
      InReg <= In;     // lock the input value this enable cycle
      mA <= z1 >>> 17;
      mB <= q;
      end
    else
      begin
      if ( run == 1'b1 )
        begin
        state <= state + 1;

        case ( state )
          
          3'd0:
            begin
            mA <= f;
            mB <= ((In18 << 18) - mP - z2) >>> 17;  
            end
          
          3'd1:
            begin
            mA <= f;
            mB <= z1 >>> 17;

            z1 <= mP + z1;
            end

          3'd2:
            begin
            z2 <= mP + z2;
            run <= 1'b0;
            end

        endcase

        end
      end
    end

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
// C source for working floating point SVF:

/*
while ( fgets( buf, BUFSIZE, stdin ) != NULL )
  {
  input = atof( buf );
    
  multq = fb1 * q;
      
  sum1 = input + (-multq) + (-output);        
  mult1 = f * sum1;

  sum2 = mult1 + fb1;      
  mult2 = f * fb1;

  sum3 = mult2 + fb2;
                  
  fb1 = sum2;
  fb2 = sum3;
                      
  output = sum3;
  printf( "%20.18lf\n", output );
  }
*/

endmodule
