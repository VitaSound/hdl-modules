// Scott Gravenhorst 01-23-2007
// nco_multi_4e
//
// requires nco_v8.v (52 bit NCO)
// supports 4 NCOs mixed, with separate tuning values from shared interpolating tuning_LUT.
// This version uses NCOs with a 52 bit accumulator.  The tuning LUT size is unchanged.
//
// Version a changes the basic logic so that the table represents the lowest octave
// possible and the octave value indicates left shifts instead of right shifts.  This
// will at least eliminate the 4 bit subtractor and will cause the octave value to 
// make more musical sense in that when it increases, the pitch increases as well.
// This change also prevents loss of significant digits which was causing small tuning errors
// resulting in phasing when 2 NCOs were set exactly one octave apart.
//
// Version b Adds amplitude control to each NCO using a shared multiplier.
// Version c Adds pitch wheel control globally to each NCO.
// Version d Supports single RAM based multi NCO. Restoring portamento.
//           Remove unnecessary clocks and unnecessary states in state machine.
// Version e Add pitch noise modulation, separate noise gen per NCO


module nco_multi_4e ( out, clk50mhz, ena, reset,
  noteoct0, noteoct1, noteoct2, noteoct3,           // note and octave numbers (4 bits each)
  fineTUNE0,  fineTUNE1,  fineTUNE2,  fineTUNE3,    // NCO fine tune values
  WAVsel0, WAVsel1, WAVsel2, WAVsel3,               // wave form select
  PWMctrl0, PWMctrl1, PWMctrl2, PWMctrl3,           // PWM control values
  level0, level1, level2, level3,                   // nco levels
  nzmod0, nzmod1, nzmod2, nzmod3,                   // noise filter modulation values
  nzbw0, nzbw1, nzbw2, nzbw3,                       // noise filter bw values
  PORTtime0, PORTtime1, PORTtime2, PORTtime3,       // portamento time values
  TUNEglob,                                         // 15 bits: global tuning
  PW );                                             // Pitch Wheel input

  output signed [17:0] out;          // mixed output of NCOs
  input clk50mhz;                    // system clock
  input ena;                         // clocks out to DAC
  input reset;                       // reset what needs reset

  input [7:0] noteoct0;            // 4 bits of note, 4 bits of octave
  input [7:0] noteoct1;            //
  input [7:0] noteoct2;            //
  input [7:0] noteoct3;            //

  input signed [14:0] fineTUNE0;
  input signed [14:0] fineTUNE1;
  input signed [14:0] fineTUNE2;
  input signed [14:0] fineTUNE3;

  input [1:0] WAVsel0;
  input [1:0] WAVsel1;
  input [1:0] WAVsel2;
  input [1:0] WAVsel3;

  input [6:0] PWMctrl0;            // PWM control value for NCO0
  input [6:0] PWMctrl1;            // PWM control value for NCO1
  input [6:0] PWMctrl2;            // PWM control value for NCO2
  input [6:0] PWMctrl3;            // PWM control value for NCO3

  input [13:0] level0;
  input [13:0] level1;
  input [13:0] level2;
  input [13:0] level3;

  input [13:0] nzmod0, nzmod1, nzmod2, nzmod3;
  input [4:0] nzbw0, nzbw1, nzbw2, nzbw3;

  input [17:0] PORTtime0;
  input [17:0] PORTtime1;
  input [17:0] PORTtime2;
  input [17:0] PORTtime3;

  input [14:0] TUNEglob;        // tuning value presented by rotary encoder logic
  
  input [13:0] PW;
  
///////////////////////////////////////////////////////////////////////////////

  wire [13:0] level0;
  wire [13:0] level1;
  wire [13:0] level2;
  wire [13:0] level3;
  
  wire [13:0] nzmod0, nzmod1, nzmod2, nzmod3;
  wire [4:0] nzbw0, nzbw1, nzbw2, nzbw3;
   
  wire [17:0] PORTtime0;
  wire [17:0] PORTtime1;
  wire [17:0] PORTtime2;
  wire [17:0] PORTtime3;
  reg  [17:0] port_time;

  reg nco_clk=0;
  reg portamento_clk=0;
  
  wire signed [17:0] out;
  
  reg  signed [17:0] out0_reg, out1_reg, out2_reg, out3_reg;
  wire signed [14:0] fineTUNE0, fineTUNE1, fineTUNE2, fineTUNE3;
  
  wire [1:0] WAVsel0, WAVsel1, WAVsel2, WAVsel3;
  reg [1:0] wave_sel;

  wire [6:0] PWMctrl0, PWMctrl1, PWMctrl2, PWMctrl3;     // supplied as module inputs
  reg [6:0] PWMctrl;                                       // sent to NCO module per unit by state machine
  
  wire [7:0] noteoct0;
  wire [7:0] noteoct1;
  wire [7:0] noteoct2;
  wire [7:0] noteoct3;
  
  wire [14:0] TUNEglob;

  wire signed [18:0] mixer01;
  wire signed [18:0] mixer23;
  wire signed [19:0] mixer;

  wire [51:0] phase_inc;                 // phase_inc bus expanded to 52 bits, octave adjusted
  wire [51:0] phase_inc_portamento;      // this is the output of the portamento_multi module, it is the phase
                                         // increment data stream passed through the multiplierless IIR filter.  

  wire [35:0] scaled_raw_nz;

/////////////////////////////////////////////////////////
// NCOs - This instantiates a single NCO module that is RAM based and implements 4 NCOs.

  reg [1:0] sel = 0;                 // selects NCO to operate on.
  wire [17:0] nco_out;
  
  wire [51:0] nco_input;
  wire signed [51:0] scaled_raw_nz_sign_ext;
  
  
// Sign extend scaled raw nz to 52 bits, left shift for magnitude
  assign scaled_raw_nz_sign_ext = { {2{scaled_raw_nz[35]}}, scaled_raw_nz[35:0], 14'b00000000000000 };  
  
  assign nco_input = phase_inc_portamento + scaled_raw_nz_sign_ext ;
  
  nco_v8 NCO (
    .clk( clk50mhz ), 
    .unit( sel ),
    .reset( reset ), 
    .phase_inc( nco_input ),    // 52 bits, scaled nz may need more or less than 20 bits of shifting 
    .out( nco_out ),            // 18 bits
    .wave_sel( wave_sel ),      // 2 bits
    .PWMctrl( PWMctrl ),        // 18'h00000 = 50% duty cycle
    .nco_clk( nco_clk )         // S.M. clocks new sum into phase accumulator
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Portamento, 4 X IIR

  portamento_multi PRTMNTO (
    .clk50mhz( clk50mhz ),               // system clock
    .portamento_clk( portamento_clk ),   // clocks the IIR register
    .clk_div( port_time ),               // controls portamento time by varying sample rate of IIR filter
    .bw( 3'b000 ),                       // set to largest # of samples to stabilize.
    .in( phase_inc ),                    // input, phase increment value stream.
    .out( phase_inc_portamento ),        // phase increment value, filtered 
    .unit( sel )                         // selects which NCO upon which to operate
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interpolating Pitch LUT - uses one multiplier

  reg [3:0] note_number_reg;
  reg [3:0] octave_reg;
//  reg signed [15:0] fineTUNEreg;
  reg signed [14:0] fineTUNEreg;
  wire [35:0] raw_phase_inc;             // raw phase increment value from tuning LUT module
  wire [15:0] tuning_sum;

  assign tuning_sum = {1'b0,TUNEglob} + fineTUNEreg ;       // add global tuning value to individual values

  tuning_interp_v2 INTRP0 
    ( 
    .note( note_number_reg ),
    .data_out( raw_phase_inc[35:0] ),    // data_out is 36 bits, will be left shifted 'octave' times.
    .tuning( tuning_sum[14:0] )          // Interpolate on this
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interpolating Pitch Wheel LUT - uses one multiplier
  wire [17:0] PW_Multiplier;             // phase increment multiplier from pitchwheel LUT output.

  PW_Interp INTRP1 (
    .PW( PW ),           // 14 bits unsigned, Raw pitchwheel value from MIDI data
    .data_out( PW_Multiplier )           // 18 bits unsigned, Pitch WHeel Multiplier
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// tuning value (input to tuning_LUT) MUX

  wire [35:0] phase_inc_times_wheel;   // product of phase_inc X pitchwheel LUT output
  
// Pitch Wheel math.  PI_Multipler is supplied by PW_LUT
  assign phase_inc_times_wheel = raw_phase_inc[35:18] * PW_Multiplier ;

// Do octave shifting here.  Left shifting provides octaves up without precision loss.
  assign phase_inc = phase_inc_times_wheel << ( octave_reg ) ;  

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// 4 nz generators, 64, 63, 62 and 61 bit LFSR
// separate generators of different bit types will force distinctive character

  wire [17:0] nz61_out;
  wire [17:0] nz62_out;
  wire [17:0] nz63_out;
  wire [17:0] nz64_out;
  reg nz61_ena;         // reg used by state machine to enable each nz generator in sequence
  reg nz62_ena;         // reg used by state machine to enable each nz generator in sequence
  reg nz63_ena;         // reg used by state machine to enable each nz generator in sequence
  reg nz64_ena;         // reg used by state machine to enable each nz generator in sequence
  
  reg [17:0] nz_level;
  reg signed [17:0] nz;        // this is a pipeline register used by the state machine to select 
//  reg  [17:0] nz;        // this is a pipeline register used by the state machine to select 
                               // and hold the current state's nz value
  wire [35:0] nz_levelctrld;

  noise61bit NZ61 ( .out( nz61_out ), .clk( clk50mhz ), .ena( nz61_ena ), .filter_bw( nzbw0[4:0] ) );
  noise62bit NZ62 ( .out( nz62_out ), .clk( clk50mhz ), .ena( nz62_ena ), .filter_bw( nzbw1[4:0] ) );
  noise63bit NZ63 ( .out( nz63_out ), .clk( clk50mhz ), .ena( nz63_ena ), .filter_bw( nzbw2[4:0] ) );
  noise64bit NZ64 ( .out( nz64_out ), .clk( clk50mhz ), .ena( nz64_ena ), .filter_bw( nzbw3[4:0] ) );


// noise gets clocked with each nz gen in state machine, 
// this calculation provides nz scaled by the pitch value.
//                                           phase_inc_portamento, take 17 bits X nz, add this to phase increment applied to NCO, see NCO instantiation
  
//  assign scaled_raw_nz = {1'b0,phase_inc_portamento[41:25]} * nz_levelctrld[35:18] ;

// use sysex parameters to control the amount of nz.  See state machine, nz_level is a pipeline.
//  assign nz_levelctrld = nz * nz_level ;

// NOTE:
// These multipliers are primitive instantiations because of my frustration with trying to get 
// WebPACK ISE to infer what I wanted.  Either it would use too many multipliers or the design
// didn't function correctly.  So if you're porting this to an FPGA other than a Xilinx XC3S500E,
// I apologize and hope that you can figure out how to make these multiplies work with inference.
// Please feel free to email me at music.maker@gte.net to show me how (c:

MULT18X18SIO #(
.AREG(0), // Enable the input registers on the A port (1=on, 0=off)
.BREG(0), // Enable the input registers on the B port (1=on, 0=off)
.B_INPUT("DIRECT"), // B cascade input "DIRECT" or "CASCADE"
.PREG(0) // Enable the input registers on the P port (1=on, 0=off)
) MULT18X18SIO_inst0 (
.BCOUT(), // 18-bit cascade output
.P( nz_levelctrld ), // 36-bit multiplier output
.A( nz ),            // 18-bit multiplier input
.B( nz_level ),      // 18-bit multiplier input
.BCIN(18'h00000),
.CEA(1'b0), .CEB(1'b0), .CEP(1'b0), .CLK(1'b0), .RSTA(1'b0), .RSTB(1'b0), .RSTP(1'b0)
);

MULT18X18SIO #(
.AREG(0), // Enable the input registers on the A port (1=on, 0=off)
.BREG(0), // Enable the input registers on the B port (1=on, 0=off)
.B_INPUT("DIRECT"), // B cascade input "DIRECT" or "CASCADE"
.PREG(0) // Enable the input registers on the P port (1=on, 0=off)
) MULT18X18SIO_inst1 (
.BCOUT(), // 18-bit cascade output
.P( scaled_raw_nz ), // 36-bit multiplier output
.A( {1'b0,phase_inc_portamento[41:25]} ),            // 18-bit multiplier input
.B( nz_levelctrld[35:18] ),      // 18-bit multiplier input
.BCIN(18'h00000),
.CEA(1'b0), .CEB(1'b0), .CEP(1'b0), .CLK(1'b0), .RSTA(1'b0), .RSTB(1'b0), .RSTP(1'b0)
);


  
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// set up multiplier for sharing as level control

  wire signed [35:0] levelprod_full;
  wire signed [17:0] p;
  reg signed [17:0] a_reg;
  reg [13:0] b_reg;
  wire signed [17:0] b;
  
  assign b = {1'b0,b_reg,3'b000};
  
  assign levelprod_full = a_reg * b;

  assign p = levelprod_full[35:18];
  
/////////////////////////////////////////////////////////
// 4 way summing mixer output connections
  
  assign mixer01 = out0_reg + out1_reg;
  assign mixer23 = out2_reg + out3_reg;
  assign mixer = mixer01 + mixer23;
  assign out = mixer >>> 1;  // this should really be >>> 2, not sure why 1 gives proper amplitude yet. // divide by 4 because we're adding 4 NCOs

// SHARING CONTROL STATE MACHINE
  reg [4:0] state=5'h0;
  reg run=1'b0;

  always @ ( posedge clk50mhz )
    begin
    if ( ena )
      begin                                // this is really the state machine's first state.
      run <= 1'b1;
      state <= 5'h00;                      // go to state 00 next cycle
      note_number_reg <= noteoct0[3:0];  octave_reg <= noteoct0[7:4]; 
      port_time <= PORTtime0;
      fineTUNEreg <= fineTUNE0;
      wave_sel <= WAVsel0;
      PWMctrl <= PWMctrl0;
      portamento_clk <= 0; nco_clk <= 0;                       // make sure all clocks are zero
      nz61_ena <= 1;                                        // ok here, doesn't depend on sel
      nz_level <= {1'b0,nzmod0,3'b000};
      sel <= 2'b00;                                            // select NCO
      end
    else
      begin
      if ( run )
        begin
        case ( state )
        
        5'h00: begin state <= 5'h01; portamento_clk <= 1; nz61_ena <= 0; nz <= nz61_out; end // clock portamento output
      
        5'h01: begin state <= 5'h02; nco_clk <= 1; portamento_clk <= 0; end 
       
        5'h02: begin state <= 5'h03; a_reg <= nco_out; b_reg <= level0; nco_clk <= 0; end
          
        5'h03:
          begin
          out0_reg <= p;                                                     // capture NCO output value, level adjusted.       
          state <= 5'h04;
          wave_sel <= WAVsel1;
          PWMctrl <= PWMctrl1;
          port_time <= PORTtime1;
          note_number_reg <= noteoct1[3:0];  octave_reg <= noteoct1[7:4];  fineTUNEreg <= fineTUNE1;
          nz62_ena <= 1;
          nz_level <= {1'b0,nzmod1,3'b000};
          sel <= 2'b01;                                                      // select NCO
          end

        5'h04: begin state <= 5'h05; portamento_clk <= 1; nz62_ena <= 0; nz <= nz62_out; end // clock portamento output
         
        5'h05: begin state <= 5'h06; nco_clk <= 1; portamento_clk <= 0; end
        
        5'h06: begin state <= 5'h07; a_reg <= nco_out; b_reg <= level1; nco_clk <= 0; end
      
        5'h07:
          begin
          out1_reg <= p;                                                     // capture NCO output value, level adjusted.       
          state <= 5'h08;
          wave_sel <= WAVsel2;
          PWMctrl <= PWMctrl2;
          port_time <= PORTtime2;
          note_number_reg <= noteoct2[3:0];  octave_reg <= noteoct2[7:4];  fineTUNEreg <= fineTUNE2;
          nz63_ena <= 1;
          nz_level <= {1'b0,nzmod2,3'b000};
          sel <= 2'b10;                                                      // select NCO
          end

        5'h08: begin state <= 5'h09; portamento_clk <= 1; nz63_ena <= 0; nz <= nz63_out; end // clock portamento output
         
        5'h09: begin state <= 5'h0A; nco_clk <= 1; portamento_clk <= 0; end

        5'h0A: begin state <= 5'h0B; a_reg <= nco_out; b_reg <= level2; nco_clk <= 0; end
    
        5'h0B:
          begin
          out2_reg <= p;                                                     // capture NCO output value, level adjusted.       
          state <= 5'h0C;
          wave_sel <= WAVsel3;
          PWMctrl <= PWMctrl3;
          port_time <= PORTtime3;
          note_number_reg <= noteoct3[3:0];  octave_reg <= noteoct3[7:4];  fineTUNEreg <= fineTUNE3;
          nz64_ena <= 1;
          nz_level <= {1'b0,nzmod3,3'b000};
          sel <= 2'b11;                                                      // select NCO
          end

        5'h0C: begin state <= 5'h0D; portamento_clk <= 1; nz64_ena <= 0; nz <= nz64_out; end // clock portamento output
         
        5'h0D: begin state <= 5'h0E; nco_clk <= 1; portamento_clk <= 0; end

        5'h0E: begin state <= 5'h0F; a_reg <= nco_out; b_reg <= level3; nco_clk <= 0; end

        5'h0F: 
          begin 
          out3_reg <= p;                                // capture NCO output value, level adjusted.        
          run <= 1'b0;                                  // end this enable cycle.
          end
       
        endcase
      end
    end
  end
endmodule
