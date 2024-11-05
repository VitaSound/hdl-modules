// i2s_out.v:
// 2008-08-26 E. Brombaugh
//
// modified by S. Gravenhorst, configured for 200 KHz sample rate
// with DCM generated 38.4 MHz clock
//
module i2s_out( clk, reset, l_data, r_data, sdout, sclk, lrclk, load );
  
  parameter DIV = 192;           // Set the divider ratio here, not in clkgen.v
  parameter HI_COUNTER_BIT = 1;  // divide by 4
  // note: the above two parameters should divide to a quotient of 48

/////////////////////////////////////////////////////////////////////////////////  

  input clk;                  // System clock
  input reset;                // System POR
  input signed [23:0] l_data; // left input
  input signed [23:0] r_data; // right input
  output sdout;               // I2S serial data
  output sclk;                // I2S serial clock
  output lrclk;               // I2S Left/Right clock
  output load;                // Sample rate enable output
  
  // Sample rate generation
  clkgen #(.DIVIDER(DIV)) uclk (.clk( clk ), .reset( reset ), .rate( load ));

  // Serial Clock divider
  
  reg [HI_COUNTER_BIT:0] scnt = 2'b00;    // serial clock divide register
  always @ ( posedge clk )
    begin
    if ( reset )        scnt <= 0;
    else if ( load )    scnt <= 0;
    else                scnt <= scnt + 1;
    end
    
  // generate serial clock pulse
  reg p_sclk;      // 1 cycle wide copy of serial clock
  always @ ( posedge clk ) p_sclk <= ~|scnt;  // for multibit counter
 
  // Shift register advances on serial clock
  reg [47:0] sreg;
  always @ ( posedge clk )
    if ( load )         sreg <= {l_data,r_data};
    else if ( p_sclk )  sreg <= {sreg[46:0],1'b0};
  
  // 1 serial clock cycle delay on data relative to LRCLK
  reg sdout;
  always @ ( posedge clk ) if ( p_sclk )  sdout <= sreg[47];
  
  // Generate LR clock
  reg [4:0] lrcnt = 5'b00000;
  reg lrclk = 1'b0;
  always @ ( posedge clk )
    begin
    if ( reset | load )           // if reset or load is true, reset lrcnt and lrclk to zero
      begin
      lrcnt <= 0;
      lrclk <= 0;
      end
    else 
      begin
      if ( p_sclk )
        begin
        if( lrcnt == 5'd23 )
          begin
          lrcnt <= 0;
          lrclk <= ~lrclk;
          end
        else
          lrcnt <= lrcnt + 1;
        end
      end
    end
    
  // align everything
  reg sclk_p0, sclk;
  always @ ( posedge clk )
    begin
    sclk_p0 <= scnt[HI_COUNTER_BIT];        // div by n counter top bit
    sclk <= sclk_p0;
    end
endmodule
