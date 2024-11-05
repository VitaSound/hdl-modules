`timescale 1ns / 1ps
// Scott R. Gravenhorst
// 2007-01-13
//
// GateMan I
//
// Uses PicoBlaze interrupt driven MIDI controller
//
// Ver.
// 1.00  Fix tuning table problem and expand tuning table bitwidth from 17 to 22 bits.
// 1.01  Add second NCO and state machine for controlling it.
// 1.02  MONOSYNTH_SG0004b seems to have some tuning problem in the lower register.
//       Seems most apparent when the NCOs are tuned a small amount apart, +/- 160 ?
//       The tuning table being right shifted for octave appears to be causing resolution loss
//       Perhaps we should be upshifting instead and use more bits in the NCO counter.
//       This version imports the SRC for NCO_v3 to modify it this way to test this theory.
// 1.03  Theory in 1.02 seems correct, the problem is gone in version 'b'.  Version 'c'
//       uses the tuning table as the lowest octave instead of the highest.  In this version,
//       the octave value will be the number of left shifts and thus it's musical sense will
//       no longer be backwards.
// 1.04  Added TTY UART.  midictrl.psm treats both UARTs as inputs to MIDI stream so that
//       system exclusive data messages can be received by either UART.  
//       Registers writable by the MCU created for synth parameters.  Update by sysex.
//       Lots of problems with nco_multi_4a state machine, it seems OK now.
// 1.05  removing sysex message type byte, adding model number byte
//       Using nco_multi_4b, b version adds amplitude control over each NCO while sharing 1 multiplier.
// 1.06  Add portamento to nco_v5 creating nco_v6
// 1.07  NCF ADSR parameters
// 1.08  Clear out lower 128 address space for sysex messages.  All others are moved to above 127.
// 1.09  Add AMP, AMP is used to compensate for amplitude loss caused by the filter.
//       Note that AMP can be set too high such that distortion is caused.
// 1.10  Add second byte to I/O address space for expanded sysex parameter support.
// Ih    Changed portamento to use RAM instead of registers for storage to allow for sharing.
//       NCO still uses registers, but they are addressable.  Registers make parameter setting
//       easier.
//       Add SRC routing for PWM
// Ii    Fix read_strobe being used as a clock to using it as an enable with clk50mhz -
//         Changing to simple pipeline clocked by clk50mhz works, but no effect on GCLK count.
// Ij    Add pitch noise modulation with 4 separate noise generators, 64, 63, 62 and 61 bit.
// Il    Pieline cuber.  Gets rid of timing constrain error.
// Im    Add IIR filter to noise generators.
//       Having problem with replacing CHANpres with MOD_WHL - synth stops working,
//       replacement done in selector for sustain level.
// In    Experiment to correct problem with MX selection in NCF ADSR sustain modulation
// Ip    NCA ADSR sustain modulation by velocity.
// Iq    Cleanup, re-enable sustain modulation in NCA ADSR
// Ir    Portamento time extended from 7 bits to 14.  Also removed shifter for portamento time (clk_div)
//       in module portamento_multi to give more resolution on the low time end.
// Is    Return all multiply operations to code which will infer them.
// It    Add reset to nco_v8
//       
///////////////////////////////////////////////////////////////////////////////////////////////////
// PROJECT RENAMED GateMan I.
// GateMan Ia supports pitchwheel messages.
// GateMan Ib adds sysex NCA ADSR control
//         AMP setting enabled
//         add sysex NCF MIN value

// The slide switches provide MIDI channel configuration.  
// Switches should be set to MIDI_channel - 1 in binary.  The switches are sampled whenever a complete.
// MIDI message is received so the effect of the switches is immediate.

// MIDI System Exclusive Message structure:
// MFR ID
// MODEL NUMBER
// UNIT NUMBER
// PARAMETER ADDRESS MSB
// PARAMETER ADDRESS LSB
// PARAMETER DATA 

module GateMan_I ( clk50mhz, led,
                 lcd_rs, lcd_rw, lcd_e, lcd_d, 
                 rotary_a, rotary_b, rotary_press,
                 BTN_EAST, BTN_WEST,
                 spi_sck, spi_sdi, spi_dac_cs, spi_sdi, spi_sdo, spi_rom_cs, 
                 spi_amp_cs, spi_adc_conv, spi_dac_cs, spi_amp_shdn, spi_dac_clr,
                 strataflash_oe, strataflash_ce, strataflash_we,
                 platformflash_oe,
                 switch, 
                 Raw_MIDI_In,
                 TTY_In
                 );

  input clk50mhz;
  output [7:0] led;
  
  inout [7:4] lcd_d;
  output lcd_rs;
  output lcd_rw;
  output lcd_e;
  
  input rotary_a;
  input rotary_b;
  input rotary_press;
  
  input BTN_EAST;
  input BTN_WEST;     // master tune multiplier, when pushed, causes increment of 16 instead of 1.
  
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

  input [3:0] switch;
  input Raw_MIDI_In;
  input TTY_In;

  wire [7:4] lcd_d;
  wire lcd_rs;
  wire lcd_rw;
  wire lcd_rw_control;
  wire lcd_e;
  wire lcd_drive;
  
  reg [7:0] LCD;
  
  assign lcd_d[7:4] = ( lcd_drive == 1'b1 & lcd_rw_control == 1'b0 ) ? LCD[7:4] : 4'bzzzz;
  assign lcd_drive = LCD[3];
  assign lcd_rs = LCD[2];
  assign lcd_rw_control = LCD[1];
  assign lcd_e = LCD[0];
  assign lcd_rw = lcd_rw_control & lcd_drive;

  reg [11:0] DACreg = 12'b000000000000;  // used by SPI DAC

  reg [7:0] led_reg;

  wire clk50mhz;
  wire [7:0] led;
  wire [7:0] ledA;
  wire [7:0] ledF;

  wire [14:0] ROT_value_out;      // output from rotary encoder's register
  
  wire DACena;

  wire BTN_EAST, BTN_WEST;

//  wire rotary_press_out;

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
  wire proc_reset;                // an output from the mcu ROM, not sure what it's supposed to connect to.
  reg [7:0] in_port_reg;          // hold data for mcu
  assign in_port = in_port_reg;

// MIDI & TTY receivers
  wire [7:0] rx0data;
  wire rx0ready_status;
  wire reset_rx0ready_status;
  
  wire [7:0] rx1data;
  wire reset_rx1ready_status;

  wire resetsignal;
// mcu
  wire read_strobe;
  wire write_strobe;

// output vectors
  wire [11:0] DACbus;

// Synth signals

  reg [6:0] SYSEX_ADDR_MSB = 7'h00;

// hardware ports that mcu writes to
// 8 bit:
  reg [7:0] NOTEOCT0;
  reg [7:0] NOTEOCT1;
  reg [7:0] NOTEOCT2;
  reg [7:0] NOTEOCT3;
  reg [7:0] MCU_LED;
// 7bit:  (these are supplied by sysex messages, thus are restricted to 7 bits.
  reg [6:0] CHANpres;
  reg [13:0] PW = 14'b10000000000000;  // init pitch wheel at center in case it never sends a message
  reg [6:0] MOD_WHL;
  reg [6:0] JOYSTKx;
  reg [6:0] JOYSTKy;
  reg [6:0] VEL;
  
  reg [6:0] CRSTUNE0 = 7'h00;     // half steps. static value for now
  reg [6:0] CRSTUNE1 = 7'h00;     // half steps. static value for now
  reg [6:0] CRSTUNE2 = 7'h00;     // half steps. static value for now
  reg [6:0] CRSTUNE3 = 7'h00;     // half steps. static value for now

  reg [6:0] TRANSPOSE = 7'h00;              // global transposition in half steps

  reg [6:0] AMP = 7'h00;

  reg [13:0] FINTUNE0;
  reg [13:0] FINTUNE1;
  reg [13:0] FINTUNE2;
  reg [13:0] FINTUNE3;
  
// 1 bit:
  reg       MCU_GATE = 1'b0;                 // one bit.
  reg       old_GATE = 1'b0;
  wire      GATEchgd;  
  always @ (posedge clk50mhz) old_GATE <= MCU_GATE;
  assign GATEchgd = MCU_GATE ^ old_GATE;       // true whenever gate signal changes state.

///////////////////////////////////////////////////////////////////////////////////////  
// 2 bit wave selects for each NCO
  reg [1:0] WAVSEL0;
  reg [1:0] WAVSEL1;
  reg [1:0] WAVSEL2;
  reg [1:0] WAVSEL3;
///////////////////////////////////////////////////////////////////////////////////////  
// 14 bit level controls for each NCO

  reg [13:0] LEV0;
  reg [13:0] LEV1;
  reg [13:0] LEV2;
  reg [13:0] LEV3;
  
///////////////////////////////////////////////////////////////////////////////////////  

// portamento time registers

  reg [13:0] PRTtime0;
  reg [13:0] PRTtime1;
  reg [13:0] PRTtime2;
  reg [13:0] PRTtime3;

///////////////////////////////////////////////////////////////////////////////////////  

  reg [13:0] NCFadsrA;
  reg [13:0] NCFadsrD;
  reg [13:0] NCFadsrS;
  reg [13:0] NCFadsrR;
  reg [13:0] NCFpk;
  reg [11:0] NCFmin;

///////////////////////////////////////////////////////////////////////////////////////  

  reg [13:0] NCAadsrA;
  reg [13:0] NCAadsrD;
  reg [13:0] NCAadsrS;
  reg [13:0] NCAadsrR;

///////////////////////////////////////////////////////////////////////////////////////  

  reg [1:0] PWMmodSRC0;
  reg [1:0] PWMmodSRC1;
  reg [1:0] PWMmodSRC2;
  reg [1:0] PWMmodSRC3;
  
///////////////////////////////////////////////////////////////////////////////////////  

  reg [13:0] NZmod0;
  reg [13:0] NZmod1;
  reg [13:0] NZmod2;
  reg [13:0] NZmod3;
  
///////////////////////////////////////////////////////////////////////////////////////  

  reg [1:0] NCFpkMODsrc;
  reg [1:0] NCFsusMODsrc;
  
///////////////////////////////////////////////////////////////////////////////////////  

  reg [4:0] NOISEbw0;   // noise filter bw values
  reg [4:0] NOISEbw1;
  reg [4:0] NOISEbw2;
  reg [4:0] NOISEbw3;

///////////////////////////////////////////////////////////////////////////////////////  

  reg [1:0] NCApeakMODsrc;
  reg [1:0] NCAsusMODsrc;

///////////////////////////////////////////////////////////////////////////////////////  

  reg [6:0] PWMcfg0;   // PWM static configured values
  reg [6:0] PWMcfg1;
  reg [6:0] PWMcfg2;
  reg [6:0] PWMcfg3;

///////////////////////////////////////////////////////////////////////////////////////
// POR delay FF chain - taken from Eric Brombaugh's code for the SPI DAC.
  FDCE rst_bit0 (.Q(rstd[0]), .C(clk50mhz), .CE(1'b1), .CLR(1'b0), .D(1'b1));
  FDCE rst_bit1 (.Q(rstd[1]), .C(clk50mhz), .CE(1'b1), .CLR(1'b0), .D(rstd[0]));
  FDCE rst_bit2 (.Q(rstd[2]), .C(clk50mhz), .CE(1'b1), .CLR(1'b0), .D(rstd[1]));
  FDCE rst_bit3 (.Q(rstd[3]), .C(clk50mhz), .CE(1'b1), .CLR(1'b0), .D(rstd[2]));
  assign reset = ~rstd[3] | BTN_EAST;    // use east button as reset.

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
    .reset(proc_reset|reset), .clk(clk50mhz) );  

  midictrl PSM_ROM0 ( .address(address), .instruction(instruction), .proc_reset(proc_reset), .clk(clk50mhz) );
  
  // MIDI receiver.  31,250 Baud
  assign resetsignal = write_strobe && ( port_id == 8'hFF );  // When port_id == FF with write strobe, reset the UARTs
  assign MIDI_In = Raw_MIDI_In;                    // Don't invert the MIDI serial stream for 6N138
  // assign MIDI_In = ~Raw_MIDI_In;                // Invert the MIDI serial stream

///////////////////////////////////////////////////////////////////////////////////////
// MIDI UART
  MIDIuartrx UARTrx0 ( .dout(rx0data), .clk(clk50mhz), .reset(resetsignal), .rxd(MIDI_In), 
    .frame(), .overrun(), .ready(), .busy(), .CS(), 
    .interrupt(interrupt0), .interrupt_ack(interrupt_ack), 
    .rxready_status(rx0ready_status), 
    .reset_rxready_status(reset_rx0ready_status)
    );
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////
  // decode read port 01, send pulse to reset rxready flop
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata.
  assign reset_rx0ready_status = (read_strobe == 1'b1) & (port_id == 8'h01);

///////////////////////////////////////////////////////////////////////////////////////
// TTY UART, 115.2 or 19.2 kilobuad (baudrate configured in module)
  TTYuartrx UARTrx1 ( .dout(rx1data), .clk(clk50mhz), .reset(resetsignal), .rxd(TTY_In), 
    .frame(), .overrun(), .ready(), .busy(), .CS(), 
    .interrupt(interrupt1), .interrupt_ack(interrupt_ack), 
    .rxready_status(rx1ready_status), 
    .reset_rxready_status(reset_rx1ready_status)
    );
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////
  // decode read port 08, send pulse to reset rxready flop
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata.
  assign reset_rx1ready_status = (read_strobe == 1'b1) & (port_id == 8'h08);

// common
  assign interrupt = (interrupt0 | interrupt1);  // ISR gets to figure out which UART did it.

///////////////////////////////////////////////////////////////////////////////
// Synth component interconnection objects:

  wire gate;                     // state of gate is maintained by kcpsm3

  wire signed [35:0] NCAout;
  wire signed [17:0] NCA_ctrl;

// NCF:
  wire signed [35:0] freq;
  reg signed [17:0] FILTreg;
  wire signed [35:0] FILTbus;

// NCF ADSR:
  wire signed [17:0] rawNCFadsrOUT;

// NCO output buses
  wire signed [17:0] NCOout;          // for multi NCO module

///////////////////////////////////////////////////////////////////////////////
// ports from MCU
  assign gate = MCU_GATE;             // single bit
  
///////////////////////////////////////////////////////////////////////////////
// multi NCO
  wire [6:0] PWMmod0SRC;
  wire [6:0] PWMmod1SRC;
  wire [6:0] PWMmod2SRC;
  wire [6:0] PWMmod3SRC;

  wire [6:0] PWMmod0MX0;  
  wire [6:0] PWMmod0MX1;  
  wire [6:0] PWMmod1MX0;  
  wire [6:0] PWMmod1MX1;  
  wire [6:0] PWMmod2MX0;  
  wire [6:0] PWMmod2MX1;  
  wire [6:0] PWMmod3MX0;  
  wire [6:0] PWMmod3MX1;  

  reg  [6:0] VEL_NOT;
  reg  [6:0] MOD_WHL_A;
  reg  [6:0] CHANpres_NOT;
  
  always @ ( posedge clk50mhz )        // distribute loading better?  Doesn't seem to fix anything tho.
    begin
    CHANpres_NOT <= ~CHANpres;
    VEL_NOT <= ~VEL;
    MOD_WHL_A <= MOD_WHL;
    end

// PWM modulation routing
  assign PWMmod0MX0 = PWMmodSRC0[0] ? CHANpres_NOT : PWMcfg0 ;
  assign PWMmod0MX1 = PWMmodSRC0[0] ? MOD_WHL_A : VEL_NOT ;
  assign PWMmod0SRC = PWMmodSRC0[1] ? PWMmod0MX1 : PWMmod0MX0;

  assign PWMmod1MX0 = PWMmodSRC1[0] ? CHANpres_NOT : PWMcfg1 ;
  assign PWMmod1MX1 = PWMmodSRC1[0] ? MOD_WHL_A : VEL_NOT ;
  assign PWMmod1SRC = PWMmodSRC1[1] ? PWMmod1MX1 : PWMmod1MX0; 

  assign PWMmod2MX0 = PWMmodSRC2[0] ? CHANpres_NOT : PWMcfg2 ;
  assign PWMmod2MX1 = PWMmodSRC2[0] ? MOD_WHL_A : VEL_NOT ;
  assign PWMmod2SRC = PWMmodSRC2[1] ? PWMmod2MX1 : PWMmod2MX0; 

  assign PWMmod3MX0 = PWMmodSRC3[0] ? CHANpres_NOT : PWMcfg3 ;
  assign PWMmod3MX1 = PWMmodSRC3[0] ? MOD_WHL_A : VEL_NOT ;
  assign PWMmod3SRC = PWMmodSRC3[1] ? PWMmod3MX1 : PWMmod3MX0; 

  nco_multi_4e NCO_MULT (
    .out( NCOout), 
    .clk50mhz( clk50mhz ), 
    .ena( DACena ), 
    .reset( reset ), 
    .noteoct0( NOTEOCT0 ),
    .noteoct1( NOTEOCT1 ),
    .noteoct2( NOTEOCT2 ),
    .noteoct3( NOTEOCT3 ),
    .fineTUNE0( {FINTUNE0,1'b0} ), 
    .fineTUNE1( {FINTUNE1,1'b0} ), 
    .fineTUNE2( {FINTUNE2,1'b0} ), 
    .fineTUNE3( {FINTUNE3,1'b0} ), 
    .WAVsel0( WAVSEL0 ),
    .WAVsel1( WAVSEL1 ),
    .WAVsel2( WAVSEL2 ),
    .WAVsel3( WAVSEL3 ),
    .PWMctrl0( PWMmod0SRC ),
    .PWMctrl1( PWMmod1SRC ),
    .PWMctrl2( PWMmod2SRC ),
    .PWMctrl3( PWMmod3SRC ),
    .level0( LEV0 ),
    .level1( LEV1 ),
    .level2( LEV2 ),
    .level3( LEV3 ),
    .nzmod0( NZmod0 ),
    .nzmod1( NZmod1 ),
    .nzmod2( NZmod2 ),
    .nzmod3( NZmod3 ),
    .nzbw0( NOISEbw0 ), 
    .nzbw1( NOISEbw1 ), 
    .nzbw2( NOISEbw2 ), 
    .nzbw3( NOISEbw3 ),
    .PORTtime0( {4'h0,PRTtime0} ),
    .PORTtime1( {4'h0,PRTtime1} ),
    .PORTtime2( {4'h0,PRTtime2} ),
    .PORTtime3( {4'h0,PRTtime3} ),
    .TUNEglob( ROT_value_out ),
    .PW( PW )
    );

///////////////////////////////////////////////////////////////////////////////
// Connect output (and convert signed arithmetic to unsigned DAC requirment)

  assign DACbus = (NCAout[34:23]<<<AMP) + 12'b100000000000 ;

///////////////////////////////////////////////////////////////////////////////
// NCA

  wire [16:0] NCAsus;        // MX out select MX0 or 
  wire [6:0] NCAsusMODMX;        // MX out select pressure or velocity

  assign NCAsusMODMX = NCAsusMODsrc[0] ? MOD_WHL : VEL ;
  assign NCAsus = NCAsusMODsrc[1] ? {NCAsusMODMX,10'b0000000000} : {NCAadsrS,3'h0} ;
  
  nca NCA1(
      .datain( FILTreg ),        // 18 bits
      
		// remove NCF altogether for this test.
		//.datain( NCOout ),        // 18 bits
		
      .ctrl( NCA_ctrl ),         // 18 bits
      .dataout( NCAout )         // 36 bits
      );

  nca_adsr ADSR_NCA (
      .ADSRout( NCA_ctrl ),                  // 18 bits
      .clock( clk50mhz ), 
      .GATE( gate ), 
		.GATEchgd( GATEchgd ),
      .a_rate( {NCAadsrA,4'h0} ),            // 18 bits, 18'h3FFFF = full scale
      .d_rate( {NCAadsrD,4'h0} ),            // 18 bits, 18'h3FFFF = full scale
      .SUSlev( {1'b0,NCAsus} ),              // 18 bits, 18'h0 to 18'h1FFFF
      .r_rate( {NCAadsrR,4'h0} ),		      // 18 bits, 18'h3FFFF = full scale
		.led( ledA )
      );

///////////////////////////////////////////////////////////////////////////////
// NCF

// Provide offset for freq1 from freq so that a low end limit can be set
  reg [11:0] freq1;  // cuber input is 12 bits
  reg signed [35:0] Delay;
  wire signed [35:0] CubeOut;

  always @ ( posedge clk50mhz ) freq1 <= freq[11:0] + NCFmin;

  RecursiveFilterMath1Stage_a IIR (
      .DataIn( NCOout ),              // 18 bits  you can select tri_out, saw_out or pwm_out in the NCO module
      .Delay( Delay ),                // 36 bits
      .PrevData( FILTreg ),           // 18 bits
      .DataOut( FILTbus )             // 36 bits
      );

//////// Cuber
//////// Approximately cube the input value 'freq1' to form CubeOut.
//////// Also subtract the value from max value.
////////
  wire [35:0] p0;
  wire [35:0] p1;
  assign p0 = freq1 * freq1;
  assign p1 = freq1 * p0[23:7];                     // freq1 ^ 3
  assign CubeOut = 36'sh7FFFFFFFF - ( p1 << 7 );    // freq converts to delay here, x128 to restore magnitude.
  always @ ( posedge clk50mhz ) Delay <= CubeOut;   // pipeline for cuber
///////

  always @ ( posedge clk50mhz ) 
  begin
    if ( DACena ) 
    begin
      DACreg <= DACbus;
      FILTreg <= FILTbus >>> 18; // this provides the filter stored feedback
    end
  end

// This assign restores the magnitude of freq for the NCF.  The PEAK_VALUE is shifted left
// for proper ADSR timescale with 18 bit input values, however, this value is then too large for the 
// NCF, hence the correction in this assign.  The number of shifts is calculated by subtracting 18 
// (number of shifts provided by ADSR module) from 26 (the adjustment made to the PEAK_VALUE parameter) 
// giving 8.
// Note that the sum of sus_level, offset value (see above) and the PEAK_VALUE (without shifting)
// must not exceed decimal value 3250 or weird things happen to the filter.
  assign freq = rawNCFadsrOUT >>> 8;
// ADSR  -- PEAK_VALUE must be a 38 bit constant parameter, this is the maximum value the ADSR 
// will attain at the end of ATTACK.
//  ncf_adsr #( .PEAK_VALUE( 38'd3250 << 24 ) ) ADSR_NCF (     // this must be limited to a value <= 3250 (CB2).

// ncf ADSR peak value modulation
  wire [6:0] ncf_peak_modSRC;    // MX output selecting mod wheel or velocity
  wire [13:0] ncf_peak_val;          // applied to ADSR, MX out of 

  assign ncf_peak_modSRC = NCFpkMODsrc[0] ? MOD_WHL : VEL ;

  wire [13:0] p2;
     // unsigned multiplier created out of adders:
  assign p2 = {7'b0000000,ncf_peak_modSRC} + {3'b000,ncf_peak_modSRC,4'b000} + {2'b00,ncf_peak_modSRC,5'b00000} ;
  assign ncf_peak_val = NCFpkMODsrc[1] ? ( p2 + 14'h004B ) : NCFpk ;  // max = C67 , so we can add 0x4B.	 

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// sustain level modulation
  wire [6:0] ncf_sus_modMX0;   // MX out select pressure or velocity
  wire [17:0] NCFsus;          // MX out select MX0 or 

  assign ncf_sus_modMX0 = NCFsusMODsrc[0] ? MOD_WHL : VEL ;
       
  assign NCFsus = NCFsusMODsrc[1] ? {ncf_sus_modMX0,10'b0000000000} : {1'b0,NCFadsrS,3'h0} ;
//                                                                        ^^ config value ^^

  ncf_adsr ADSR_NCF (
      .ADSRout( rawNCFadsrOUT ),             // 18 bits
      .clock( clk50mhz ), 
      .GATE( gate ), 
		.GATEchgd( GATEchgd ),
      .a_rate( {NCFadsrA,4'h0} ),            // 18 bits, 18'h3FFFF = full scale
      .d_rate( {NCFadsrD,4'h0} ),            // 18 bits, 18'h3FFFF = full scale
      .SUSlev( NCFsus ),                     // 18 bits, 18'h0 to 18'h1FFFF
      .r_rate( {NCFadsrR,4'h0} ),            // 18 bits, 18'h3FFFF = full scale
      .ADSRpkVAL( {ncf_peak_val,4'h0} ),     // 18 bits
      .led( ledF )
      );
		
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Rotary Encoder - special version for this project
//               
  RotaryEncoder_v2 ENC (
    .clk( clk50mhz ), 
    .rotary_a( rotary_a ), 
    .rotary_b( rotary_b ), 
    .rotary_press( rotary_press ), 
    .BTN_WEST( BTN_WEST ),
    .value_out( ROT_value_out ), 
    .rotary_press_out( rotary_press_out )
    );

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DAC, module by Eric Brombaugh
  spi_dac_out DAC (
     .clk( clk50mhz ), 
     .reset( reset), 
     .spi_sck( spi_sck ), 
     .spi_sdo( spi_sdi ), 
     .spi_dac_cs( spi_dac_cs ), 
     .ena_out( DACena ), 
     .data_in( DACreg )      // use upper 12 bits
     );

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////  
// Decode structures for hardware receiving data from the MCU

  always @ ( posedge clk50mhz )
  begin
    if ( write_strobe == 1'b1 )
   begin
// This case block contains selection logic for system level ports and for CC ports.
// Note that these ports all have the bit 7 or port_id set.
     case ( port_id )
      8'hF0: CHANpres    <= out_port[6:0];  // channel pressure value, global
      8'hF1: PW[13:7]    <= out_port[6:0];  // pitch wheel MSB, global
      8'hF2: PW[6:0]     <= out_port[6:0];  // pitch wheel LSB, global
      8'hF3: MOD_WHL     <= out_port[6:0];  // modulation wheel, global
      8'hF4: JOYSTKx     <= out_port[6:0];  // JOYSTK X, global
      8'hF5: JOYSTKy     <= out_port[6:0];  // JOYSTK Y, global
//      8'hF6: VOICE_SEL <= out_port[6:0];  // For poly, selects the voice to talk to when 
//      8'hF7: SUSTAIN     <= out_port[6:0];  // FF when depressed, 00 when not depressed.
      8'hF8: MCU_GATE    <= out_port[0];    // MCU_GATE signal, per voice, right now just one voice.
      8'hF9: VEL         <= out_port[6:0];  // port to set synth hardware velocity register, per voice
      8'hFA: NOTEOCT0    <= out_port;       // Note nybbles used to select the phase increment from pitch LUT
      8'hFB: NOTEOCT1    <= out_port;       //    "
      8'hFC: NOTEOCT2    <= out_port;       //    "
      8'hFD: NOTEOCT3    <= out_port;       //    "
    
      8'hFE: MCU_LED <= out_port;
//    8'hFF: reset both UARTs.  See area of instantiation of UARTs    

      8'hE0: SYSEX_ADDR_MSB <= out_port;
		
      8'h90: LCD <= out_port;
     endcase
//////////////////////////////////////////////////////////////////////////////////////////
// These if blocks contain case blocks for sysex populated parameters     
// below this, all port_id values have bit 7 set to zero
// Address space is 14 bits.

     if ( SYSEX_ADDR_MSB == 8'h00 )
       begin
       case ( port_id )
       // SYSEX updatable parameter ports:    
       // NOTE about CRS_TUNE: The summing of CRS_TUNE values with NOTEOCT values is done in the MCU.
       8'h00: CRSTUNE0     <= out_port[6:0];
       8'h01: CRSTUNE1     <= out_port[6:0];
       8'h02: CRSTUNE2     <= out_port[6:0];
       8'h03: CRSTUNE3     <= out_port[6:0];
       // micro tune, only 7 bits used in each port    

       8'h04: FINTUNE0[13:7] <= out_port[6:0];   // MSB
       8'h05: FINTUNE0[6:0]  <= out_port[6:0];   // LSB
       8'h06: FINTUNE1[13:7] <= out_port[6:0];   // MSB
       8'h07: FINTUNE1[6:0]  <= out_port[6:0];   // LSB 
       8'h08: FINTUNE2[13:7] <= out_port[6:0];   // MSB
       8'h09: FINTUNE2[6:0]  <= out_port[6:0];   // LSB
       8'h0A: FINTUNE3[13:7] <= out_port[6:0];   // MSB
       8'h0B: FINTUNE3[6:0]  <= out_port[6:0];   // LSB
 
       8'h0C: WAVSEL0      <= out_port[1:0];
       8'h0D: WAVSEL1      <= out_port[1:0];
       8'h0E: WAVSEL2      <= out_port[1:0];
       8'h0F: WAVSEL3      <= out_port[1:0];
 
       8'h10: TRANSPOSE    <= out_port[6:0];   // global transpose by semitones, neg values don't work - fix this
     
       8'h11: AMP          <= out_port[6:0];
 
       8'h12: LEV0[13:7]   <= out_port[6:0];   // MSB
       8'h13: LEV0[6:0]    <= out_port[6:0];   // LSB
       8'h14: LEV1[13:7]   <= out_port[6:0];   // MSB
       8'h15: LEV1[6:0]    <= out_port[6:0];   // LSB
       8'h16: LEV2[13:7]   <= out_port[6:0];   // MSB
       8'h17: LEV2[6:0]    <= out_port[6:0];   // LSB
       8'h18: LEV3[13:7]   <= out_port[6:0];   // MSB
       8'h19: LEV3[6:0]    <= out_port[6:0];   // LSB
		 
 /* These were expanded to 14 bits each and to preserve the existing map, moved to new addresses
       8'h1A: PRTtime0     <= out_port[6:0];
       8'h1B: PRTtime1     <= out_port[6:0];
       8'h1C: PRTtime2     <= out_port[6:0];
       8'h1D: PRTtime3     <= out_port[6:0];
 */
       8'h1E: NCFadsrA[13:7] <= out_port[6:0];
       8'h1F: NCFadsrA[6:0]  <= out_port[6:0];
       8'h20: NCFadsrD[13:7] <= out_port[6:0];
       8'h21: NCFadsrD[6:0]  <= out_port[6:0];
       8'h22: NCFadsrS[13:7] <= out_port[6:0];
       8'h23: NCFadsrS[6:0]  <= out_port[6:0];
       8'h24: NCFadsrR[13:7] <= out_port[6:0];
       8'h25: NCFadsrR[6:0]  <= out_port[6:0];
       8'h26: NCFpk[13:7]    <= out_port[6:0];
       8'h27: NCFpk[6:0]     <= out_port[6:0];
       8'h28: NCFmin[11:7]   <= out_port[4:0];
       8'h29: NCFmin[6:0]    <= out_port[6:0];

       8'h2A: NCAadsrA[13:7] <= out_port[6:0];
       8'h2B: NCAadsrA[6:0]  <= out_port[6:0];
       8'h2C: NCAadsrD[13:7] <= out_port[6:0];
       8'h2D: NCAadsrD[6:0]  <= out_port[6:0];
       8'h2E: NCAadsrS[13:7] <= out_port[6:0];
       8'h2F: NCAadsrS[6:0]  <= out_port[6:0];
       8'h30: NCAadsrR[13:7] <= out_port[6:0];
       8'h31: NCAadsrR[6:0]  <= out_port[6:0];
		 
       8'h32: PWMmodSRC0   <= out_port[1:0];
       8'h33: PWMmodSRC1   <= out_port[1:0];
       8'h34: PWMmodSRC2   <= out_port[1:0];
       8'h35: PWMmodSRC3   <= out_port[1:0];

       8'h36: NZmod0[13:7] <= out_port[6:0];   // MSB
       8'h37: NZmod0[6:0]  <= out_port[6:0];   // LSB
       8'h38: NZmod1[13:7] <= out_port[6:0];   // MSB
       8'h39: NZmod1[6:0]  <= out_port[6:0];   // LSB
       8'h3A: NZmod2[13:7] <= out_port[6:0];   // MSB
       8'h3B: NZmod2[6:0]  <= out_port[6:0];   // LSB
       8'h3C: NZmod3[13:7] <= out_port[6:0];   // MSB
       8'h3D: NZmod3[6:0]  <= out_port[6:0];   // LSB
		 
       8'h3E: NCFpkMODsrc  <= out_port[1:0];
       8'h3F: NCFsusMODsrc <= out_port[1:0];

       8'h40: NOISEbw0   <= out_port[4:0];
       8'h41: NOISEbw1   <= out_port[4:0];
       8'h42: NOISEbw2   <= out_port[4:0];
       8'h43: NOISEbw3   <= out_port[4:0];

       8'h44: NCApeakMODsrc <= out_port[1:0];
       8'h45: NCAsusMODsrc  <= out_port[1:0];

       8'h46: PRTtime0[13:7] <= out_port[6:0];   // MSB
       8'h47: PRTtime0[6:0]  <= out_port[6:0];   // LSB
       8'h48: PRTtime1[13:7] <= out_port[6:0];   // MSB
       8'h49: PRTtime1[6:0]  <= out_port[6:0];   // LSB
       8'h4A: PRTtime2[13:7] <= out_port[6:0];   // MSB
       8'h4B: PRTtime2[6:0]  <= out_port[6:0];   // LSB
       8'h4C: PRTtime3[13:7] <= out_port[6:0];   // MSB
       8'h4D: PRTtime3[6:0]  <= out_port[6:0];   // LSB

       8'h4E: PWMcfg0        <= out_port[6:0];
       8'h4F: PWMcfg1        <= out_port[6:0];
       8'h50: PWMcfg2        <= out_port[6:0];
       8'h51: PWMcfg3        <= out_port[6:0];
 
       endcase
       end
/////////////////////////////////////////////////////////////////////////////////////////////
/*
// Use this for parameter address space extension.  Each block created like this one must
// have a unique SYSEX_ADDR_MSB value which cannot be larger than 127
     if ( SYSEX_ADDR_MSB == 7'b01 )
       begin
       case ( port_id )
       endcase
       end       
*/
    end
  end

// make sure that in_port_reg always contains selected data at rising edge of clk50mhz,
// PicoBlaze will read it when it needs it.
  always @ ( posedge clk50mhz ) 
  begin
    case ( port_id[3:0] )                        // decode and transfer data to in_port_reg
    4'h0: in_port_reg <= {rx1ready_status,rx0ready_status,6'b000000}; // UART1 & UART0 rxready bits
    4'h1: in_port_reg <= rx0data;                   // MIDI UART rxdata
    4'h2: in_port_reg <= {4'b0000,switch};          // slide switches
    4'h3: in_port_reg <= {1'b0,CRSTUNE0}; // CRS pitch offset for NCO0 (half steps, signed)
    4'h4: in_port_reg <= {1'b0,CRSTUNE1}; // CRS pitch offset for NCO1 (half steps, signed)
    4'h5: in_port_reg <= {1'b0,CRSTUNE2}; // CRS pitch offset for NCO2 (half steps, signed)
    4'h6: in_port_reg <= {1'b0,CRSTUNE3}; // CRS pitch offset for NCO3 (half steps, signed)
    4'h7: in_port_reg <= {1'b0,TRANSPOSE};
    4'h8: in_port_reg <= rx1data;                   // TTY UART rxdata
	 endcase
  end

//////////////////////////////////////////////////////

// monitor both ADSR state values
  assign led = {1'b0,ledF[2:0],1'b0,ledA[2:0]} ;

////////////////////////////////////////////////////
////////////////////////////////////////////////////
  // clock data into MCU_LEDs.
/*
  always @ ( posedge clk50mhz )
  begin
    led_reg <= MCU_LED;                        // hook MCU_LEDs to uC MCU_LED port
//    led_reg <= z_led;
//    led_reg <= ROT_value_out[7:0];
  end
*/  

/*
reg [7:0] counter = 8'h00;
always @ (posedge gate)
begin
 counter <= counter + 1;
end
assign led = counter;
*/

////////////////////////////////////////////////////

endmodule
