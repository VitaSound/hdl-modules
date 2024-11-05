// Engineer: Scott Gravenhorst
// email: music.maker@gte.net
// Date: 01-23-2007
// nco_multi_f
//
// requires nco_v9.v (48 bit phase accum NCO)
// supports 4 NCOs mixed, with separate tuning values from shared interpolating tuning_LUT.
// This version uses NCOs with a 48 bit accumulator.  The tuning LUT size is unchanged.
//
// Version a changes the basic logic so that the table represents the lowest octave
// possible and the octave value indicates left shifts instead of right shifts.  This
// will at least eliminate the 4 bit subtractor and will cause the octave value to 
// make more musical sense in that when it increases, the pitch increases as well.
// This change also prevents loss of significant bits which was causing small tuning errors
// resulting in phasing when 2 NCOs were supposed to be exactly one octave apart.
//
// Version b Adds amplitude control to each NCO using a shared multiplier.
// Version c Adds pitch wheel control globally to each NCO.
// Version d Supports single RAM based multi NCO. Restoring portamento.
//           Remove unnecessary clocks and unnecessary states in state machine.
// Version e Add pitch noise modulation, separate noise gen per NCO
// Version f For sine_synth.  Tightened the state machine.
//           Configure state machine to loop once for each NCO.
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Note about noise filter: The noise filter is meant to create slow changing random values.  The IIR filter
// does this, but also reduces the output excursion range.  With noise input, the filter's output assumes a value 
// centered on 1/2 it's full value.  The state machine subracts 18'sh10000 (1/2 full value) first and then 
// multiplies the result by the compensator value (noise gen level).  After the product is calculated, 18'sh10000
// is added back to restore it's value.  Use the compensator to control how much modulation affects the NCO level
// and use the NCO level to control the harmonic's general "weight".
//
// I now notice that (obviously), the reduced noise amplitude being simply multiplied by a slider value will
// increase it's amplitude, but the number of bits of precision lost in the filter aren't restored.  To fix this,
// I performed an experiment using 22 bit noise into a 22 bit IIR and window to get better precision.  More bits 
// than 22 may actually be required, 22 is just a test guess.
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

module nco_multi_f ( out, clk, ena, reset, sel0, sel4, sel5, noteoct, finTUN, lev, NZbw, NZgenLev, 
                      PRTtim, TUNglob, PW, /*CHANpres,*/ MOD_WHL, VEL, harmonic, MIXERshifts, NoiseWindow,
                      NCOled );

  parameter NCOMAX = 1;              // this will be changed by the instantiating module  OVER-RIDDEN BY INSTATIATING MODULE
  parameter SEL_WIDTH = 2;           // how many bits for "sel" signal?  OVER-RIDDEN BY INSTATIATING MODULE
  
  parameter NOISE_WIDTH = 48;
  
  output signed [17:0] out;           // mixed output of NCOs
  input                clk;           // system clock
  input                ena;           // DACena
  input                reset;         // reset what needs reset
  output        [SEL_WIDTH-1:0] sel0;  // NCO select 
  output        [SEL_WIDTH-1:0] sel4;  // NCO select 
  output        [SEL_WIDTH-1:0] sel5;  // NCO select 

  input         [7:0]  noteoct;       // 4 bits of note, 4 bits of octave
  input signed  [14:0] finTUN;        // fine tuning (master tune)
  input         [13:0] lev;           // NCO output level
  input         [4:0]  NZbw;          // noise filter bandwidth
  input         [13:0] NZgenLev;      // noise filter output level
  input         [17:0] PRTtim;        // portamento time
  input         [14:0] TUNglob;       // tuning value presented by rotary encoder logic
  input         [13:0] PW;            // pitch wheel value
//  input         [6:0]  CHANpres;     // channel pressure value
  input         [6:0]  MOD_WHL;       // modulation wheel
  input         [6:0]  VEL;           // velocity
  input         [5:0]  harmonic;      // harmonic number (1=fundamental)
  input         [2:0]  MIXERshifts;   // controllable mixer shifts
  input         [5:0]  NoiseWindow;   

  output        [7:0]  NCOled; wire [7:0] NCOled;
    
///////////////////////////////////////////////////////////////////////////////

//  wire         [SEL_WIDTH-1:0]  sel;  // NCO select 
  reg          [SEL_WIDTH-1:0]  sel0 = 0;              // selects NCO to operate on.
  reg          [SEL_WIDTH-1:0]  sel1 = 0;              // selects NCO to operate on. (shadows sel0)
  reg          [SEL_WIDTH-1:0]  sel2 = 0;              // selects NCO to operate on. (shadows sel0)
  reg          [SEL_WIDTH-1:0]  sel3 = 0;              // selects NCO to operate on. (shadows sel0)
  reg          [SEL_WIDTH-1:0]  sel4 = 0;              // selects NCO to operate on. (shadows sel0)
  reg          [SEL_WIDTH-1:0]  sel5 = 0;              // selects NCO to operate on. (shadows sel0)

  wire         [13:0] lev;
  wire         [4:0]  NZbw;
  wire         [13:0] NZgenLev;
  wire         [17:0] PRTtim;
  reg          [17:0] port_tim;
  reg                 nco_ena = 0;
  reg                 portamento_clk = 0;
  wire signed  [17:0] out;
  wire signed  [14:0] finTUN;
//  wire         [6:0]  CHANpres;           // used in PWM mod source mux
  wire         [6:0]  MOD_WHL;            // used in PWM mod source mux
  wire         [6:0]  VEL;                // used in PWM mod source mux
  wire         [7:0]  noteoct;
  wire         [14:0] TUNglob;
  wire         [47:0] phase_inc;             // phase_inc bus expanded to 48 bits, octave adjusted
  wire         [47:0] phase_inc_portamento;  // this is the output of the portamento_multi module, it holds the phase incremenet value
  wire         [5:0]  harmonic;              // frequency multiplier value.
  wire         [2:0]  MIXERshifts;  // controllable mixer shifts
  wire         [5:0]  NoiseWindow;

/////////////////////////////////////////////////////////
// LFSR with IIR filter for noise
  wire        [NOISE_WIDTH-1:0] LFSRout;                     // increased to 22 from 18 bits
  wire signed [NOISE_WIDTH-1:0] noise;                       // increased to 22 from 18 bits
  reg                           NZena = 1'b0;

  lfsr64bit #(.WIDTH(NOISE_WIDTH)) NZ ( .out( LFSRout ), .clk( clk ) );

  noise_iir #(.NCOMAX(NCOMAX), .SEL_WIDTH(SEL_WIDTH), .dsz(NOISE_WIDTH))
    NZIIR ( .clk( clk ), 
            .ena( NZena ), 
            .bw( NZbw ), 
            .in( LFSRout[NOISE_WIDTH-1:0] ), 
            .sel( sel1 ), 
            .out( noise ) );

// Feed 22 bit noise words to 22 bit IIR, attentuation at small bw values will reduce the amplitude.
// noise output is 22 bits wide, we will window 18 bits of it.

// Noise window
  wire signed [17:0] noise_win;
  assign noise_win = noise >>> NoiseWindow;   // NoiseWindow setting scales the noise gen output after the IIR
                                              // filter down to 18 bits.  
                                              // Larger values for NoiseWindow decrease amplitude.
  
// display absolute value of noise in LEDs to allow proper adjustment of the noise shifter
  assign NCOled = (noise_win[17]) ? -noise_win[17:10] : noise_win[17:10];

/////////////////////////////////////////////////////////
// NCOs - This instantiates a single NCO module that is RAM based and implements the NCOs.

  wire signed  [17:0]           nco_out;
  reg          [47:0]           nco_input;
  
  nco_v9 #(.SEL_WIDTH(SEL_WIDTH), .NCOMAX(NCOMAX)) NCO (
    .clk( clk ), 
    .unit( sel2 ),
    .reset( 1'b0 ), 
    .phase_inc( nco_input ),    // 48 bits, scaled nz may need more or less than 20 bits of shifting 
    .out( nco_out ),            // 18 bits
    .nco_ena( nco_ena ),        // S.M. clocks new sum into phase accumulator
    .DACena( ena ),
    .led()
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Portamento, 4 X IIR

  portamento_multi #(.SEL_WIDTH(SEL_WIDTH), .NCOMAX(NCOMAX)) PRT (
    .clk( clk ),                         // system clock
    .portamento_clk( portamento_clk ),   // clocks the IIR register
    .clk_div( port_tim ),                // controls portamento time by varying sample rate of IIR filter
    .bw( 3'b000 ),                       // set to largest # of samples to stabilize.
    .in( phase_inc ),                    // input, phase increment value stream.
    .out( phase_inc_portamento ),        // phase increment value, filtered 
    .unit( sel3 )                         // selects which NCO upon which to operate
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interpolating Pitch LUT - uses one multiplier

  reg        [3:0]  note_number_reg;
  reg        [3:0]  octave_reg;
  reg signed [14:0] finTUNreg;
  wire       [35:0] raw_phase_inc;             // raw phase increment value from tuning LUT module
  wire       [15:0] tuning_sum;

  assign tuning_sum = {1'b0,TUNglob} + finTUNreg ;       // add global tuning value to individual values

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
    .PW( PW ),                           // 14 bits unsigned, Raw pitchwheel value from MIDI data
    .data_out( PW_Multiplier )           // 18 bits unsigned, Pitch WHeel Multiplier
    );

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// tuning value (input to tuning_LUT) MUX

  wire [35:0] phase_inc_times_wheel;     // product of phase_inc X pitchwheel LUT output
  
// Pitch Wheel math.  PW_Multipler is supplied by PW_LUT
  assign phase_inc_times_wheel = raw_phase_inc[35:18] * PW_Multiplier ;

// Do octave shifting here.  Left shifting provides octaves up without precision loss.
// Add 2 to octave because the tuning ROM was designed for 1 MHz, we're running at 250 KHz.
  assign phase_inc = phase_inc_times_wheel << ( octave_reg + 3 ) ;

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// set up multiplier for sharing by state machine

  wire signed [35:0] mP;
  reg signed  [17:0] mA;
  reg signed  [17:0] mB;
  wire signed [17:0] PROD;

  assign mP = mA * mB ;
  assign PROD = mP >>> 17 ;

/////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////
// summing mixer output connections

  reg signed   [17+SEL_WIDTH:0] mixer;
  
  assign out = mixer >>> MIXERshifts;        // Scale output from mixer.
  
/////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////
// NCO STATE MACHINE
  
  reg signed [17:0] nz;                       // register to hold noise value for state machine
  
  reg [2:0] state = 3'h0;
  reg run = 1'b0;

  always @ ( posedge clk )
    begin
    if ( ena )
      begin                                        // this is really the state machine's first state.
      run   <= 1'b1;                               // turn state machine on
      state <= 3'h0;                               // go to state 00 next cycle
      mixer <= 20'h00000;                          // zero mixer register before accumulating sum
      sel0  <= 0;                                  // start with first NCO
      sel1  <= 0;                                  // start with first NCO
      sel2  <= 0;                                  // start with first NCO
      sel3  <= 0;                                  // start with first NCO
      sel4  <= 0;                                  // start with first NCO
      sel5  <= 0;                                  // start with first NCO
      end
    else
      begin
      if ( run )
        begin
        
        state <= state + 1;
        
        case ( state )

        3'h0:
          begin
          note_number_reg <= noteoct[3:0];
          octave_reg      <= noteoct[7:4];
          port_tim        <= PRTtim;
          finTUNreg       <= finTUN;
          portamento_clk  <= 1;
          end

        3'h1: 
          begin 
          nco_input      <= phase_inc_portamento * harmonic;
          nco_ena        <= 1 ;
          nz             <= noise_win;                      // get the noise output from _previous_ calculation
          portamento_clk <= 0;
          NZena          <= 1;
          end

        3'h2:
          begin
          mA      <= nz ;
          mB      <= {1'h0,NZgenLev,3'h0} ;                      // level control is compensator value
          nco_ena <= 0; 
          NZena   <= 0 ;          
          end
      
        3'h3: 
          begin 
          mA <= PROD;                                    // level controlled noise in PROD
          mB <= nco_out;                                 // NCO output
          end

        3'h4: 
          begin
          mA <= PROD ;                                   // NCO amplitude modulated by noise in PROD
          mB <= {1'b0,lev,3'b000} ;                      // NCO output level
          end

        3'h5: 
          begin       
          mixer <= mixer + {{SEL_WIDTH{PROD[17]}},PROD};      // add sign extended NCO output value to mixer sum
          state <= 3'h0;                                    // go back to state zero for the next NCO
          sel0   <= sel0 + 1;                               // select next NCO
          sel1   <= sel1 + 1;                               // select next NCO
          sel2   <= sel2 + 1;                               // select next NCO
          sel3   <= sel3 + 1;                               // select next NCO
          sel4   <= sel4 + 1;                               // select next NCO
          sel5   <= sel5 + 1;                               // select next NCO
          if ( sel0 == NCOMAX ) run <= 1'b0;                // are we done yet?
          end
          
          endcase
        end
      end
    end

endmodule
