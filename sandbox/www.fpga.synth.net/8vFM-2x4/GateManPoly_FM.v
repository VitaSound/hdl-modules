`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Scott Gravenhorst
// email: music.maker@gte.net
// 
// Create Date:     15:00:00 05/16/2008 
// Design Name:     GateManPoly_FM
// Module Name:     
// Project Name:    
// Target Devices:  xc3s500e
//
// This synthesizer is a 2-OP FM version of the GateManPoly synth.
// Sample rate is 65.1041667 KHz
//
//////////////////////////////////////////////////////////////////////////////////
//
//                                PUSH BUTTON CONTROLS:
//
//                                BTN_N : microcontroller reset
//                                                   
//   BTN_W  :                                                            BTN_E  :
//
//                                BTN_S :
//                                NCO reset ??
//        
//
///////////////////////////////////////////////////////////////////////////////////
//
// ver_a: Source taken from GateManPoly ver_n.
//        First cut of FM version.
//        ver_a starts the development by implementing 8 voices of 4 tone generator.
//        out = sin( w(t) )  [where w(t) is the current phase accumulator value
//        Each gerator is a simple sinewave output with an amplitude ADSR per tone
//        generator.
//        This cut sort of worked with as described above, there seems to be problems
//        with the state machine.  The index ADSR appears to work, the tuning ROM
//        appears to work (must check accuracy).
//        To resolve the state machine problems, simplify down to just sawtooth and
//        the index ADSR.  Also check the accuracy of the tuning ROM, it should be 
//        at concert pitch.
//
//        The problem with the original test is that I was expecting the sine table
//        to produce a valid result one clock after transferring the input value to
//        to the table.  Since the input is register it actually takes 2 clocks because
//        the sine table is in a block RAM.
//        This test version now works nicely and is properly pitch calibrated.
//
// ver_b: Implement the ratio parameter B against the "inside" sine generator
//        providing A * sin( B * w(t) )
//        This is only a proof of concept version, like ver_a.
//        Implementation of A * sin( B * w(t) ) is working by multiplying B by the 
//        phase increment value before applying it to the phase accumulator.  "A"
//        is a simple ADSR for testing in ver_b.  Pitch change due to B and waveform
//        all appear to be good.
//
// ver_c: This version will attempt to implement the entire FM formula:
//        F(t) = sin( w(t) + A * sin( B * w(t) ) )
//        "B" will remain as it was in ver_b.
//        "A" will be implemented as an ADSR with output level and an offset.
//        A = ( ADSR * lev + OFFSET )  [where ADSR is the index ADSR]
//        A method should be included in the patch editor to prevent A from
//        binary wrapping by using either the ADSR level to limit OFFSET or using
//        OFFSET to limit the ADSR level.  The output F(x) should be amplitude
//        modulated by an amplitude ADSR and NCA.
//        Start with just A = OFFSET.
//        NCA ADSR implemented for amplitude evelope.
//
// ver_d: Implement Index ADSR to allow animation of A parameter
//
//////////////////////////////////////////////////////////////////////////////////
module GateManPoly_FM( clk, led,
            lcd_rs, lcd_rw, lcd_e, lcd_d, 
            BTN_N, 
            BTN_S,
            spi_sck, spi_sdi, spi_dac_cs, spi_sdi, spi_sdo, spi_rom_cs, 
            spi_amp_cs, spi_adc_conv, spi_dac_cs, spi_amp_shdn, spi_dac_clr,
            strataflash_oe, strataflash_ce, strataflash_we,
            platformflash_oe,
            SW, 
            Raw_MIDI_In,
            TTY_In,
            );


// This parameter supplies the version number to an MCU port which is displayed in the LCD.
/////////////////////////////////////////////////////////////////////////////////////
                              //                                                   //
                              //  #     #  #####  ####    ###   ###   ###   #   #  //
                              //  #     #  #      #   #  #       #   #   #  ##  #  //
  parameter version = "d";    //   #   #   ###    ####    ###    #   #   #  # # #  //
                              //    # #    #      #  #       #   #   #   #  #  ##  //
                              //     #     #####  #   #   ###   ###   ###   #   #  //
                              //                                                   //
/////////////////////////////////////////////////////////////////////////////////////


  parameter VOICES = 8;          // set the total number of voices
  parameter DACTIME = 12'd768;   // DAC time of 768 clocks total = 65.1041667 KHz
  
  parameter LAST_VOICE = VOICES - 1;

  input clk;
  output [7:0] led;
  
  inout [7:4] lcd_d;
  output lcd_rs;
  output lcd_rw;
  output lcd_e;
  
  input BTN_N;
  input BTN_S;
  
  output spi_sck;
  output spi_sdi;
  input spi_sdo;
  output spi_rom_cs;
  output spi_amp_cs;
  output spi_adc_conv;
  output spi_dac_cs;
  output spi_amp_shdn;
  output spi_dac_clr;
  output strataflash_oe;
  output strataflash_ce;
  output strataflash_we;
  output platformflash_oe;

  input [3:0] SW;
  
  input Raw_MIDI_In;
  input TTY_In;

/////////////////////////////////////////////////////////////////////////////////////
// LCD connections and logic
  wire [7:4] lcd_d;
  wire lcd_rs;
  wire lcd_rw;
  wire lcd_rw_control;
  wire lcd_e;
  wire lcd_drive;
  
  reg [7:0] LCD;      // written by MCU
  
  assign lcd_d[7:4] = ( lcd_drive == 1'b1 & lcd_rw_control == 1'b0 ) ? LCD[7:4] : 4'bzzzz;
  assign lcd_drive = LCD[3];
  assign lcd_rs = LCD[2];
  assign lcd_rw_control = LCD[1];
  assign lcd_e = LCD[0];
  assign lcd_rw = lcd_rw_control & lcd_drive;

  wire clk;
  wire BTN_N;
  wire BTN_S;
  
  wire [3:0] rstd;                // POR delay
  wire reset;                     // POR/User reset
  
  wire interrupt;
  wire interrupt_ack;
  wire interrupt0;
  wire interrupt1;
  wire [9:0] address;             // wires to connect address lines from uC to ROM
  wire [17:0] instruction;        // uC data lines, need connection between uC and ROM
  wire [7:0] out_port;            //
  wire [7:0] in_port;             // 
  wire [7:0] port_id;
  reg  [7:0] in_port_reg;          // hold data for mcu
  assign in_port = in_port_reg;

// MIDI & TTY receivers
  wire [7:0] rx0data;
  wire rx0ready_status;
  wire reset_rx0ready_status;
  
  wire [7:0] rx1data;
  wire rx1ready_status;
  wire reset_rx1ready_status;

  wire resetsignal;
// mcu
  wire read_strobe;
  wire write_strobe;

///////////////////////////////////////////////////////////////////////////////////////
// Synth signals

  reg [VOICES-1:0] MCU_GATE = 0;

// Output values from processing of MIDI data.
//  reg [6:0] MOD_WHL = 7'd0;                      // a usable initial value
//  reg [6:0] CHANpres = 7'd0;
//  reg SUSTAIN = 1'b0;
  
  reg [6:0] VEL[VOICES-1:0];                // dist RAM
  reg [3:0] NOTE[VOICES*4-1:0];               // dist RAM
  reg [3:0] OCT[VOICES*4-1:0];                // dist RAM
  
  reg [6:0] TRANSPOSE = 7'd00;              // global transposition in half steps.  The MIDI controller reads
                                            // this value and subtracts it from all note on message note numbers.
                                            // The synth hardware sees this adjusted value.

  reg [2:0] VOX;                            // voice select.  Managed by state machine
  reg [2:0] VXa;
  reg [2:0] VXb;
  reg [2:0] VXc;
  reg [1:0] NCO;                            // NCO select.  Managed by state machine
  reg [1:0] NC1;                             // SHADOW NCO select.  Managed by state machine
  reg [1:0] NC2;                             // SHADOW NCO select.  Managed by state machine
  reg [1:0] NCO_old;                        // shadow register for quirky state machine to reduce NCO to 3 states

  reg [3:0] NT;              // state machine NOTE working register
  reg [3:0] OC;              // state machine OCTAVE working register
  reg [6:0] VL;              // state machine VEL working register
  
//  reg [13:0] PW = 14'd0;

  reg [6:0] CRSTUN[3:0];        // DIST. RAM - coarse tune registers, half setp

  reg [6:0] FINTUNhi[3:0];      // DIST. RAM - fine tune registers
  reg [6:0] FINTUNlo[3:0];      // DIST. RAM
  
  reg [6:0] LEVhi[3:0];       // DIST. RAM - level value MSB
  reg [6:0] LEVlo[3:0];       // DIST. RAM - level value LSB

// FM parameters
// These values are supplied by the patch editor as 21 bit signed values.  They are truncated here to 18 bits signed.

// INDEX_offset is the value added to the IndexADSR output before using as FM parameter A.
  reg [6:0] INDEX_offset_hi [3:0];    // RAM for modulation index parameter
  reg [6:0] INDEX_offset_lo [3:0];    // RAM for modulation index parameter
//  assign INDEX_offset = {1'b0,INDEX_offset_hi[NCO],INDEX_offset_lo[NCO],3'b000};
  reg signed [17:0] INDEX_offset;

///////////////////////////////////////////////////////////////////////////////////////  

//  reg [1:0] NCApeakMDsrc;
//  reg [1:0] NCAsusMDsrc;

///////////////////////////////////////////////////////////////////////////////////////  
// DIAGNOSTICS
//  reg [7:0] MCULED;

///////////////////////////////////////////////////////////////////////////////////////
// POR delay FF chain - taken from Eric Brombaugh's code for the SPI DAC.
  FDCE rst_bit0 (.Q(rstd[0]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(1'b1));
  FDCE rst_bit1 (.Q(rstd[1]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[0]));
  FDCE rst_bit2 (.Q(rstd[2]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[1]));
  FDCE rst_bit3 (.Q(rstd[3]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[2]));
  assign reset = ~rstd[3] | BTN_N;

// Tie off the flash enables to allow SPI to work
  assign strataflash_oe = 1'b1;
  assign strataflash_ce = 1'b1;
  assign strataflash_we = 1'b1;
  assign platformflash_oe = 1'b0;
  
// Tie off other SPI enables to isolate DAC
  assign spi_rom_cs = 1'b1;
  assign spi_amp_cs = 1'b1;
  assign spi_adc_conv = 1'b0;
  assign spi_amp_shdn = 1'b1;
  assign spi_dac_clr = 1'b1;
///////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////
// instantiate the uC (kcpsm3) with it's ROM

  kcpsm3 MCU0 ( .address(address), .instruction(instruction), .port_id(port_id), 
    .write_strobe(write_strobe), .out_port(out_port), .read_strobe(read_strobe), .in_port(in_port), 
    .interrupt(interrupt), .interrupt_ack(interrupt_ack), 
    .reset(reset), .clk(clk) );  

  midictrl PSM_ROM0 ( .address(address), .instruction(instruction), .clk(clk) );
  
  // MIDI receiver.  31,250 Baud
  assign resetsignal = write_strobe && ( port_id == 8'hFF );  // When port_id == FF with write strobe, reset the UARTs
  assign MIDI_In = Raw_MIDI_In;                    // Don't invert the MIDI serial stream for 6N138

///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
// MIDI UART                                                                            ///
// UART code by Jim Patchell                                                            ///
  MIDIuartrx RX0 ( .dout(rx0data), .clk(clk), .reset(resetsignal), .rxd(MIDI_In),       ///
    .frame(), .overrun(), .ready(), .busy(), .CS(),                                     ///
    .interrupt(interrupt0), .interrupt_ack(interrupt_ack),                              ///
    .rxready_status(rx0ready_status),                                                   ///
    .reset_rxready_status(reset_rx0ready_status)                                        ///
    );                                                                                  ///
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////////////////
  // decode read port 01, send pulse to reset rxready flop                              ///
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata. ///
  assign reset_rx0ready_status = (read_strobe == 1'b1) & (port_id[4:0] == 5'h01);       ///
                                                                                        ///
///////////////////////////////////////////////////////////////////////////////////////////
// TTY UART, 115.2 or 19.2 kilobuad (baudrate configured in module)                     ///
// UART code by Jim Patchell                                                            ///
  TTYuartrx RX1 ( .dout(rx1data), .clk(clk), .reset(resetsignal), .rxd(TTY_In),         ///
    .frame(), .overrun(), .ready(), .busy(), .CS(),                                     ///
    .interrupt(interrupt1), .interrupt_ack(interrupt_ack),                              ///
    .rxready_status(rx1ready_status),                                                   ///
    .reset_rxready_status(reset_rx1ready_status)                                        ///
    );                                                                                  ///
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////////////////
  // decode read port 04, send pulse to reset rxready flop                              ///
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata. ///
  assign reset_rx1ready_status = (read_strobe == 1'b1) & (port_id[4:0] == 5'h09);       ///
                                                                                        ///
// common interrupt signal for both serial ports.                                       ///
// ISR gets to figure out which UART did it.                                            ///
  assign interrupt = (interrupt0 | interrupt1);                                         ///
                                                                                        ///
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
// DAC - SPI interface logic
// This DAC version accepts value 'cycles' which 
// determines the amount of time between enables.

  reg [11:0] DACreg = 12'b100000000000;    // Data for SPI DAC

// DAC, module by Eric Brombaugh
  spi_dac_out DAC (.clk(clk),.reset(reset),
                   .spi_sck(spi_sck),.spi_sdo(spi_sdi),.spi_dac_cs(spi_dac_cs),
                   .ena_out( DACena ),.data_in( DACreg ),
                   .cycles( DACTIME ) );

  reg [5:0] WINDOW = 6'd0;

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
// ADSR

  reg                ADSRena = 0;    // Multi ADSR 
 
///////////////// amplitude envelope ADSR //////////////////////

  reg [3:0] NCAexpo_R;            // 0 = linear, 1 = expo

  reg [6:0] NCAadsrA_hi [3:0];
  reg [6:0] NCAadsrA_lo [3:0];

  reg [6:0] NCAadsrD_hi [3:0];
  reg [6:0] NCAadsrD_lo [3:0];

  reg [6:0] NCAadsrS_hi [3:0];
  reg [6:0] NCAadsrS_lo [3:0];

  reg [6:0] NCAadsrR_hi [3:0];
  reg [6:0] NCAadsrR_lo [3:0];

  wire signed [17:0] ampADSRout;

  wire [13:0] NCAadsrA;
  wire [13:0] NCAadsrD;
  wire [13:0] NCAadsrS;
  wire [13:0] NCAadsrR;

  assign NCAadsrA = {NCAadsrA_hi[NC2],NCAadsrA_lo[NC2]};
  assign NCAadsrD = {NCAadsrD_hi[NC2],NCAadsrD_lo[NC2]};
  assign NCAadsrS = {NCAadsrS_hi[NC2],NCAadsrS_lo[NC2]};
  assign NCAadsrR = {NCAadsrR_hi[NC2],NCAadsrR_lo[NC2]};

  ADSR #( .SIZE( 28 ) )              // a smaller value of SIZE causes the ADSR to respond more quickly 
    ADSRamp ( .out( ampADSRout ), .clk( clk ), .ena( ADSRena ),
              .sel( {VXb,NCO} ), .GATE( MCU_GATE[VXb] ), 
              .A( NCAadsrA ), .D( NCAadsrD ), .S( {NCAadsrS,3'b000} ), .R( NCAadsrR ), 
              .expo_R(NCAexpo_R[NCO]) );

///////////////// index envelope ADSR //////////////

  reg [3:0] INDEXexpo_R;

  reg [6:0] INDEXadsrA_hi [3:0];
  reg [6:0] INDEXadsrA_lo [3:0];
  
  reg [6:0] INDEXadsrD_hi [3:0];
  reg [6:0] INDEXadsrD_lo [3:0];
  
  reg [6:0] INDEXadsrS_hi [3:0];
  reg [6:0] INDEXadsrS_lo [3:0];
  
  reg [6:0] INDEXadsrR_hi [3:0];
  reg [6:0] INDEXadsrR_lo [3:0];

  wire signed [17:0] indexADSRout;

  reg  signed [17:0] indexADSRlevREG;
  reg [6:0] indexADSRlevHI [3:0];
  reg [6:0] indexADSRlevLO [3:0];

  wire [13:0] INDEXadsrA;
  wire [13:0] INDEXadsrD;
  wire [13:0] INDEXadsrS;
  wire [13:0] INDEXadsrR;

  assign INDEXadsrA = {INDEXadsrA_hi[NC1],INDEXadsrA_lo[NC1]};
  assign INDEXadsrD = {INDEXadsrD_hi[NC1],INDEXadsrD_lo[NC1]};
  assign INDEXadsrS = {INDEXadsrS_hi[NC1],INDEXadsrS_lo[NC1]};
  assign INDEXadsrR = {INDEXadsrR_hi[NC1],INDEXadsrR_lo[NC1]};

  ADSR #( .SIZE( 28 ) )              // a smaller value of SIZE causes the ADSR to respond more quickly 
    ADSRindex ( .out( indexADSRout ), .clk( clk ), .ena( ADSRena ),
              .sel( {VXb,NCO} ), .GATE( MCU_GATE[VXb] ), 
              .A( INDEXadsrA ), .D( INDEXadsrD ), .S( {INDEXadsrS,3'b000} ), .R( INDEXadsrR ), 
              .expo_R( INDEXexpo_R[NCO] ) );

///////////////////////////////////////////////////////////////////////////////////////  
///////////////////////////////////////////////////////////////////////////////////////  
// CARRIER TO MODULATION RATIO
// Supplied as 14 bits unsigned from patch editor, trimmed here to 18 bits signed
// The value in RATIO is a fixed point binary value with a range of 0 to 15.99999 in
// the following format:  (s=always positive, I=integer, F=fraction, 0=zero
//  sIIII.FFFFFFFFF0000    As such, after multiplying by w(t) which is 0.FFFFFFFFFFFFFFFFF the
// multiplier output value must be left shifted by 4 positions.

  reg [6:0] RATIO_hi [3:0];    // RAM for C/M ratio
  reg [6:0] RATIO_lo [3:0];    // RAM for C/M ratio
  wire signed [17:0] RATIO;
  assign RATIO = {1'b0,RATIO_hi[NC2],RATIO_lo[NC2],3'b000}; 

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
// Interpolating Tuner
// Phase increment value calculated by linear interpolation between two tuning tables.

  wire signed [17:0] hi;
  wire signed [17:0] lo;                  // high and low pitch ROM outputs
  
  tuning_ROM TUN ( .addr( NT ), .out_hi( hi ), .out_lo( lo ) );      // NT shadows NOTE

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// NCO

  reg signed [20:0] NCOmixer = 0;    // this has to be here because the SVF is the first thing to use it.

//////////////////////////////////////////////////////////////////////////////////////////
// Shared multipliers with signed 36 bit and signed 18 bit outputs.

/*
  reg  signed [17:0] A0;
  reg  signed [17:0] B0;
  wire signed [35:0] P0;
  wire signed [17:0] PROD0;
  assign P0 = A0 * B0;                  // shared multiplier
  assign PROD0 = P0 >>> 17;             // 18 bit signed output
*/
  reg  signed [17:0] A1;
  reg  signed [17:0] B1;
  wire signed [35:0] P1;
  wire signed [17:0] PROD1;
  assign P1 = A1 * B1;                  // shared multiplier
  assign PROD1 = P1 >>> 17;             // 18 bit signed output

  reg  signed [17:0] A2;
  reg  signed [17:0] B2;
  wire signed [35:0] P2;
  wire signed [17:0] PROD2;
  assign P2 = A2 * B2;                  // shared multiplier
  assign PROD2 = P2 >>> 17;             // 18 bit signed output

// this multiplier is dedicated to the interpolator
  reg  signed [17:0] A3;
  reg  signed [17:0] B3;
  wire signed [35:0] P3;
  wire signed [17:0] PROD3;
  reg  signed [17:0] PROD3_reg;
  assign P3 = A3 * B3;                  // shared multiplier
  assign PROD3 = P3 >>> 17;             // 18 bit signed output

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
// main state machine

  reg [13:0] LV;                    // Cache for {LEVhi[NCO],LEVlo[NCO]}

  reg [13:0] FINETUNE;
  
  reg NCOreset = 0;
// Gate change detection objects:
//  reg  [VOICES-1:0] old_GATE = 0;
 
  reg signed [20:0] MIXER = 0;
 
  reg        [4:0]  state = 5'h00;
  reg               run = 1'b0;
  
  reg        [31:0] OP1_intPhInc = 0;                          // managed by state machine
  reg        [31:0] OP1cache = 0;                              // Phase accumulator cache
  reg        [31:0] OP1 [(VOICES*4)-1:0];                      // 33 bit phase accumulator RAM.  4 per voice

  reg        [31:0] OP2_intPhInc = 0;                          // managed by state machine
  reg        [31:0] OP2cache = 0;                              // Phase accumulator cache
  reg        [31:0] OP2 [(VOICES*4)-1:0];                      // 33 bit phase accumulator RAM.  4 per voice

/////////////// WAVEFORM LOGIC /////////////////// 
// SAW to TRI to SINE waveform:
  reg  [31:0] SIN_A_ph_in;                                // store phase input to sine converter here
  wire signed [17:0] TRIoutA;
  wire signed [17:0] TRItmpA;
//  assign TRItmp0 = (OP1cache[32]) ? OP1cache[31:14] : ~OP1cache[31:14] ;
  assign TRItmpA = (SIN_A_ph_in[31]) ? SIN_A_ph_in[30:13] : ~SIN_A_ph_in[30:13] ;
  assign TRIoutA = TRItmpA + 18'b100000000000000000;

  reg  [31:0] SIN_B_ph_in;                                // store phase input to sine converter here
  wire signed [17:0] TRIoutB;
  wire signed [17:0] TRItmpB;
  assign TRItmpB = (SIN_B_ph_in[31]) ? SIN_B_ph_in[30:13] : ~SIN_B_ph_in[30:13] ;
  assign TRIoutB = TRItmpB + 18'b100000000000000000;
// SINE waveform:  
// Sine table, 1024 locations, 18 data bits, 1/4 cycle.
  wire        [9:0]  SINadrA;
  wire        [9:0]  SINadrB;
  wire signed [17:0] SIN_ROM_A;
  wire signed [17:0] SIN_ROM_B;
  
  sine_tab SIN ( .CLK( clk ), .ADDRA( SINadrA ), .ADDRB( SINadrB ), .OA( SIN_ROM_A ), .OB( SIN_ROM_B  ) );

  wire signed [17:0] SIN_out_A;
  assign SINadrA = TRIoutA[17] ? ~TRIoutA[16:7] : TRIoutA[16:7];        
  assign SIN_out_A = TRIoutA[17] ? ~SIN_ROM_A : SIN_ROM_A ;

  wire signed [17:0] SIN_out_B;
  assign SINadrB = TRIoutB[17] ? ~TRIoutB[16:7] : TRIoutB[16:7];        
  assign SIN_out_B = TRIoutB[17] ? ~SIN_ROM_B : SIN_ROM_B ;
///////////////////////////////////////////////////////////////

// linear interpolator for pitch tuning ROMs
//  reg [31:0] interp;
  reg [17:0] interp18;              // interpretation output for w(t)

// DAC
  reg  [20:0] NEXT_DAC;  
  wire [11:0] DAC_WIN;             // 12 bit movable window
  wire [20:0] DAC_SHIFTER;
  assign DAC_SHIFTER = NEXT_DAC << WINDOW;
  assign DAC_WIN = DAC_SHIFTER[20:9];

//////////////////////////////////////////////////////////////////////////////////////////

// X(t) = sin( w(t) + A * sin( B * w(t) ) )
//  A is modulation index
//  B is ratio

//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//
// state machine structure:

reg [7:0] ledreg;

//  reg [17:0] INDEX;                                    // holds index value

  always @ ( posedge clk )
    begin
    if ( DACena )
      begin
      state    <= 5'h00;                                // starting state
      run      <= 1'b1;                                 // tell state machine to run
      VOX      <= 3'b000;                               // Select voice zero to start
      VXa      <= 3'b000;                               // copy of VOX to avoid high fanout
      VXb      <= 3'b000;                               // copy of VOX to avoid high fanout
      DACreg   <= {~DAC_WIN[11],DAC_WIN[10:0]};         // REPLACES:  DACreg <= DAC_WIN + 12'h800;  No adder needed.
      MIXER    <= 0;                                    // reset output sum (MIXER)
//      old_GATE <= MCU_GATE;                             // snapshot MCU_GATE for detecting a gate change
      
      if ( BTN_S ) begin NCOreset <= 1; end
      end
    
    else        // else if NOT DACena:
      
      begin
		
      if ( run )
        begin
        case ( state ) 
        
        5'h00:                                     // initialize for this voice
          begin  state <= state + 1;
          VXa      <= VOX ;                        // shadows VOX to reduce fanout
          VXb      <= VOX ;                        // shadows VOX to reduce fanout
          VXc      <= VOX ;                        // shadows VOX to reduce fanout

          VL       <= VEL[VOX];                    // get velocity value to VL register from VEL RAM

          NCO      <= 0;
          NC1      <= 0;
          NC2      <= 0;
          NCO_old  <= 0;
          NCOmixer <= 0;
          end

        5'h01:                                     // initialize for this voice
          begin  state <= state + 1;               // ADSR state 1 complete

          NT              <= NOTE[{VXa,NCO}];          // get note number being played 
          OP1cache        <= OP1[{VXa,NC1}];           // get current OP1 phase accumulator value to cache register
          OP2cache        <= OP2[{VXa,NC2}];           // get current OP2 phase accumulator value to cache register
          FINETUNE        <= {FINTUNhi[NC1],FINTUNlo[NC1]};
          OC              <= OCT [{VXa,NC2}];
          LV              <= {LEVhi[NC2],LEVlo[NC2]};
          INDEX_offset    <= {1'b0,INDEX_offset_hi[NCO],INDEX_offset_lo[NCO],3'b000};
          indexADSRlevREG <= {1'b0,indexADSRlevHI[NCO],indexADSRlevLO[NCO],3'b000};
          end

        //////////////// START OF NCO LOOP ///////////////////////////
        5'h02:
          begin  state <= state + 1;
          ADSRena <= 1;
          end

        5'h03:
          begin  state <= state + 1;
          ADSRena <= 0;
          end
        
        5'h04:
          begin  state <= state + 1;
          SIN_A_ph_in <= {OP1cache,2'b00};          // SIN_A_ph_in (32 bits)

          A3 <= hi - lo ;                           // part of tuning interpolator
          B3 <= {1'b0,FINETUNE,3'b000} ;
          end

        5'h05:
          begin  state <= state + 1;
          interp18 <= PROD3 + lo;               // PROD3_REG (18 bits) gets interpretation output.
          
          A1 <= indexADSRout;
          B1 <= indexADSRlevREG;
          end

        5'h06:
          begin  state <= state + 1;       // wait state for sine table
          A3 <= interp18;                  // interp18 [or w(t) ]
          B3 <= RATIO;                     // times C:M ratio

          A2 <= SIN_out_A;                 // SIN_out_A = sin( B * w(t) )
          B2 <= (INDEX_offset + PROD1);              // 
          end

        5'h07:
          begin  state <= state + 1;
          OP1_intPhInc <= {{9{P3[34]}},P3[34:12]} << OC;        // OP1_intPhInc (32 bits)
          OP2_intPhInc <= {{11{interp18[17]}},interp18,3'b000} << OC;

          // PROD2 = ( A * sin( B * w(t) ) where A is just INDEX_offset for now
          SIN_B_ph_in <= (P2[34:3] + OP2cache );   
          end
          
        5'h08:
          begin  state <= state + 1;
          end
          
        5'h09:  
          begin  state <= state + 1;
          A2 <= SIN_out_B;
          B2 <= ampADSRout;
          end

        5'h0A:  
          begin  state <= state + 1;
          A2 <= PROD2;
          B2 <= {1'b0,LV,3'b000};
          end

        5'h0B:
          begin  state <= state + 1;
          NCOmixer <= NCOmixer + ({{3{PROD2[17]}},PROD2});    //   reg signed [20:0] NCOmixer = 0;

          NCO_old <= NCO;
          NCO     <= NCO + 1;
          NC1     <= NC1 + 1;
          NC2     <= NC2 + 1;

          end
        5'h0C:
          begin
          OP1[{VXa,NCO_old}] <= (BTN_S) ? 33'd0 : OP1cache + OP1_intPhInc ;   // generate next phase value
          OP2[{VXa,NCO_old}] <= (BTN_S) ? 33'd0 : OP2cache + OP2_intPhInc ;   // generate next phase value

          NT              <= NOTE[{VXa,NCO}];          // get note number being played 
          OP1cache        <= OP1[{VXa,NC1}];           // get current phase accumulator value to cache register
          OP2cache        <= OP2[{VXa,NC2}];           // get current OP2 phase accumulator value to cache register
          FINETUNE        <= {FINTUNhi[NC1],FINTUNlo[NC1]};
          OC              <= OCT [{VXa,NC2}];
          LV              <= {LEVhi[NC2],LEVlo[NC2]};
          INDEX_offset    <= {1'b0,INDEX_offset_hi[NCO],INDEX_offset_lo[NCO],3'b000};
          indexADSRlevREG <= {1'b0,indexADSRlevHI[NCO],indexADSRlevLO[NCO],3'b000};
          
          if ( NCO == 0 )  state <= state + 1;         // ESCAPE NCO LOOP
          else             state <= state - 10;        // LOOP FOR NEXT NCO
          end
          
        //////////////// END OF NCO LOOP ////////////////////////////////// 
        
        // at entering the next state, all 4 NCOs are updated and NCOmixer has the sum of all 4

        5'h0D:
          begin  state <= state + 1;

          A1 <= NCOmixer[20:3];                                // upper 18 bits of NCOmixer
          B1 <= {1'b0,VL,10'b1111111111} ;                     // modulate with velocity
          end
         
        5'h0E:                              
          begin  state <= state + 1;
          end

        5'h0F:      
          begin  state <= state + 1;
          MIXER <= MIXER +  {PROD1[17],PROD1[17],PROD1[17],PROD1} ;    // Sum Vel. modulated NCOmixer with main MIXER
          end

        5'h10:
          begin  state <= 5'h0;                           // set state to start of voice process
          VOX <= VOX + 1;                                 // select next voice

          if ( VOX == LAST_VOICE )
            begin
            run <= 1'b0;                                  // stop the state machine after all voices are processed
            NCOreset <= 0;                                // set general reset off
            NEXT_DAC <= MIXER;
            end
          end

        endcase
        end
      end
    end  

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////  
// Decode structures for hardware receiving data from the MCU

// reg [7:0] MCU_LED;

  reg [7:0] SYSEX_ADDR_MSB;

  always @ ( posedge clk )
    begin
    if ( write_strobe == 1'b1 )
      begin
// This case block contains selection logic for system level ports and for CC ports.
// Note that these ports all have the bit 7 of port_id set.
      casex ( port_id )
      8'b10000xxx: VEL[port_id[2:0]]      <= out_port[6:0];         //  80 - 87
      8'b101xxxxx: 
        begin
        NOTE[port_id[4:0]] <= out_port[3:0];        //  AO - BF
        OCT[port_id[4:0]]  <= out_port[7:4];        //  AO - BF
        end
      8'h90:       LCD                    <= out_port;
      8'h91:       SYSEX_ADDR_MSB         <= out_port;
      8'hF8:       MCU_GATE               <= out_port[7:0];  // MCU_GATE signal, 8 gate bits controlled by MCU
      endcase
      end
//////////////////////////////////////////////////////////////////////////////////////////
// These if blocks contain case blocks for sysex populated parameters     
// below this, all port_id values have bit 7 set to zero
// Address space is 14 bits.

      // SYSEX updatable parameter ports:    

    if ( write_strobe == 1'b1 )        
      begin
      if ( SYSEX_ADDR_MSB == 8'h01 )               // PAGE 01
        begin
        casex ( port_id )
        8'b000000xx: CRSTUN[port_id[1:0]]              <= out_port[6:0];   // 00 to 03        coarse tuning offset values
        
        8'b000001xx: FINTUNhi[port_id[1:0]]            <= out_port[6:0];   // 04 to 07        // micro tune, only 7 bits used in each port    
        8'b000010xx: FINTUNlo[port_id[1:0]]            <= out_port[6:0];   // 08 to 0B
        
        8'b000011xx: LEVhi[port_id[1:0]]               <= out_port[6:0];   // 0C to 0F
        8'b000100xx: LEVlo[port_id[1:0]]               <= out_port[6:0];   // 10 to 13
        
        8'b000101xx: RATIO_hi[port_id[1:0]]            <= out_port[6:0];  // 14 to 17
        8'b000110xx: RATIO_lo[port_id[1:0]]            <= out_port[6:0];  // 18 to 1B

        8'b000111xx: INDEXadsrA_hi[port_id[1:0]]       <= out_port[6:0];  // 1C - 1F
        8'b001000xx: INDEXadsrA_lo[port_id[1:0]]       <= out_port[6:0];  // 20 - 23
        8'b001001xx: INDEXadsrD_hi[port_id[1:0]]       <= out_port[6:0];  // 24 - 27
        8'b001010xx: INDEXadsrD_lo[port_id[1:0]]       <= out_port[6:0];  // 28 - 2B
        8'b001011xx: INDEXadsrS_hi[port_id[1:0]]       <= out_port[6:0];  // 2C - 2F
        8'b001100xx: INDEXadsrS_lo[port_id[1:0]]       <= out_port[6:0];  // 30 - 33
        8'b001101xx: INDEXadsrR_hi[port_id[1:0]]       <= out_port[6:0];  // 34 - 37
        8'b001110xx: INDEXadsrR_lo[port_id[1:0]]       <= out_port[6:0];  // 38 - 3B
    
        8'b001111xx: INDEXexpo_R[port_id[1:0]]           <= out_port[0];    // 3C - 3F    

        8'b01000000: WINDOW                            <= out_port[5:0];   // 40 DAC window value
        8'b01000001: TRANSPOSE                         <= out_port[6:0];   // 41 global transpose by semitones, neg values don't work - fix this
        
        8'b010001xx: INDEX_offset_hi[port_id[1:0]]     <= out_port[6:0];   // 44 - 47
        8'b010010xx: INDEX_offset_lo[port_id[1:0]]     <= out_port[6:0];   // 48 - 4B

        8'b010011xx: NCAadsrA_hi[port_id[1:0]]         <= out_port[6:0];  // 4C - 4F
        8'b010100xx: NCAadsrA_lo[port_id[1:0]]         <= out_port[6:0];  // 50 - 53
        8'b010101xx: NCAadsrD_hi[port_id[1:0]]         <= out_port[6:0];  // 54 - 57
        8'b010110xx: NCAadsrD_lo[port_id[1:0]]         <= out_port[6:0];  // 58 - 5B
        8'b010111xx: NCAadsrS_hi[port_id[1:0]]         <= out_port[6:0];  // 5C - 5F
        8'b011000xx: NCAadsrS_lo[port_id[1:0]]         <= out_port[6:0];  // 60 - 63
        8'b011001xx: NCAadsrR_hi[port_id[1:0]]         <= out_port[6:0];  // 64 - 67
        8'b011010xx: NCAadsrR_lo[port_id[1:0]]         <= out_port[6:0];  // 68 - 6B

        8'b011011xx: NCAexpo_R[port_id[1:0]]           <= out_port[0];    // 6C - 6F
        
        8'b011100xx: indexADSRlevHI[port_id[1:0]]      <= out_port[6:0];  // 70 - 73
        8'b011101xx: indexADSRlevLO[port_id[1:0]]      <= out_port[6:0];  // 74 - 77
        endcase
        end       
      end
      
/////////////////////////////////////////////////////////////////////////////////////////////
    end

// make sure that in_port_reg always contains selected data at rising edge of clk,
// PicoBlaze will read it when it needs it.
  always @ ( posedge clk ) 
    begin
    casex ( port_id[3:0] )                               // decode and transfer data to in_port_reg
    4'h0:    in_port_reg <= {rx1ready_status,rx0ready_status,6'b000000}; // UART1 & UART0 rxready bits
    4'h1:    in_port_reg <= rx0data;                     // MIDI UART rxdata
    4'h2:    in_port_reg <= {4'b0000,SW};                // slide switches

    4'b01xx: in_port_reg <= {1'b0,CRSTUN[port_id[1:0]]}; // CRS pitch offset for NCO0 (half steps, signed) 04-07

    4'h8:    in_port_reg <= {1'b0,TRANSPOSE};
    4'h9:    in_port_reg <= rx1data;                     // TTY UART rxdata
//    4'hA:    in_port_reg <= ACTIVE;                      // sounding state of each voice  - may not be required
    4'hF:    in_port_reg <= version;                     // The GateMan version number stored in hardware
    default: in_port_reg <= 8'bxxxxxxxx;
	  endcase
    end

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
// LEDs

  assign led = MCU_GATE;           // DEFAULT 

//assign led = ledreg;

endmodule
//      8'hF0:       CHANpres               <= out_port[6:0];  // channel pressure value, global
//      8'hF1:       PW[13:7]               <= out_port[6:0];  // pitch wheel MSB, global
//      8'hF2:       PW[6:0]                <= out_port[6:0];  // pitch wheel LSB, global
//      8'hF3:       MOD_WHL                <= out_port[6:0];  // modulation wheel, global
//      8'hFC:       SUSTAIN                <= out_port[6];    // sustain command register
//      8'hFE:       MCU_LED                <= out_port[7:0];
