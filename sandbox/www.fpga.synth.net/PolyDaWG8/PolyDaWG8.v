`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Scott Gravenhorst
// email: music.maker@gte.net
// 
// Create Date:     15:17:09 06/25/2007 
// Design Name:     Digital Waveguide Polyphonic Synthesizer
// Module Name:     PolyDaWG8
// Project Name:    Digital Waveguide Polyphonic Synthesizer
// Target Devices:  xc3s500e
//
// Karplus-Strong single delay line model with pickup position.
//
// String loop waveguide: 2048 location by 18 bit wide RAMs (block).
// Comb Filter: one 256 location by 18 bit wide RAM (distributed).
// Sample Rate: 250,000 samples per second.
//
//////////////////////////////////////////////////////////////////////////////////
//
//                                PUSH BUTTON CONTROLS:
//
//                                BTN_N : microcontroller reset
//                                                   
//   BTN_W  : filter delta multiplier (64x)                    BTN_E  : no function
//
//                                BTN_S : switch between rotary 
//                                        encoder and pickup
//                                        position setting number
//
//////////////////////////////////////////////////////////////////////////////////
//
//                               ROTARY ENCODER PUSHBUTTON:
//
//    Selects between two pickup position modes (shown in LCD lower right corner):
//    N - Normal, 8 equal size zones on the modulation wheel, each zone selects
//        a different algorithm for computing pickup position from the waveguide
//        length.  See code for details, some settings are bassy, some more treble
//        and each with varying amounts of "key follow".
//
//    O - Original, the modulation wheel sets the pickup distance which is the same
//        value for all strings.
//                                   
///////////////////////////////////////////////////////////////////////////////////
//
// ver_g:  8 string version.
//         output level from summer was too high, set to >>> 10 from >>> 9
//
// ver_h:  Experimenting with ways to slow squelch so that the sound is not so
//         stark.  Seems very good.  Damp time can be adjusted.
//         See: parameter sq_cnt_MAX, increase for longer damp time.
//
// ver_i:  Experimenting with controlling pickup position using waveguide length
//         to see if the sound can be made more consistent across the instrument's 
//         range.  ver_h has a very pleasant, but unique sound in that the lower
//         register is very metalic while higher notes have a choral handbell
//         character.  I would like to be able to keep that but also allow 
//         configuring the instrument for more consistent tone (esp. for strings).
//           Seems to work well, there is a nice selection of 8 tonal qualities
//           manifest by pickup positions.  In all cases, pickup position is to some
//           degree dependant upon the note played as well as the mod wheel setting.
//           SETTING     CHARACTER
//              0        very treble, low moderate keyboard tracking
//              1        treble, moderate keyboard tracking
//              2        full keyboard tracking
//              3        bass, moderate keyboard tracking
//              4        bass, low moderate keyboard tracking
//              5        bass, low keyboard tracking
//              6        very bass, slight keyboard tracking
//              7        bassiest, very slight keyboard tracking
//
// ver_k:  See how lean we can make the state machine...  Starting at 14 clocks per string.
//         Down to one clock for startup and 6 additional clocks for each string.  
//         Total of 49 for the entire harp.  Max sample rate = 1 MHz.
//
// ver_l:  Fix voice assign anomoly, requires addition of ACTIVE[STR] flag for each voice as
//         well as MIDI controller changes.  Each voice's ACTIVE bit is on if the string is
//         active (usually this means vibrating, but the string could attenuate to zero).  
//         The state if the ACTIVE flag is set to 1 when the string is plucked.  It is set
//         to 0 if both the string's gate and sustain are off.
//
// ver_l3: Converted design from flipflop heavy to RAM based.  Removed comb filter for this version.
//         Works as of 2007-11-04
//
//    l3a: Add comb filter back in
//
// ver_m:  fix tuning, first live note is the lowest B.
//
// ver_n:  Rework tuning ROM and allow tuning via changing the sample rate.
//         Changed filter state machine, it now works in 3 clocks instead of 4 clocks.
//         This shortens the total clocks to 57 from 65 per sample.
//
//////////////////////////////////////////////////////////////////////////////////
module PolyDaWG8( clk, led,
            lcd_rs, lcd_rw, lcd_e, lcd_d, 
            ROTa, ROTb,
            ROTpress,
            BTN_E, 
            BTN_W, 
            BTN_N, 
            BTN_S,
            spi_sck, spi_sdi, spi_dac_cs, spi_sdi, spi_sdo, spi_rom_cs, 
            spi_amp_cs, spi_adc_conv, spi_dac_cs, spi_amp_shdn, spi_dac_clr,
            strataflash_oe, strataflash_ce, strataflash_we,
            platformflash_oe,
            SW, 
            Raw_MIDI_In,
            TTY_In,
            cfg );

  parameter S = 8;               // set the total number of strings
  
  parameter SRdiv = 4;           // sample rate divider.  8 = 125 KHz, 4 = 250 KHz, 2 = 500 KHz, 1 = 1 MHz
  parameter SRdiv1 = SRdiv - 1;  // used in sample rate divider always block

  parameter DACTIME = 12'd92;

  input clk;
  output [7:0] led;
  
  inout [7:4] lcd_d;
  output lcd_rs;
  output lcd_rw;
  output lcd_e;
  
  input ROTa;
  input ROTb;
  
  input BTN_E;
  input BTN_W;
  input BTN_N;
  input BTN_S;
  input ROTpress;
  
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
  
  input cfg;
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

/////////////////////////////////////////////////////////////////////////////////////

  reg [7:0] led_reg;

  wire clk;
  wire [14:0] ROTval;      // output from rotary encoder's register
//  wire BTN_E;
  wire BTN_W;
  wire BTN_N;
  wire BTN_S;
  wire ROTpress;           // raw rotary button output
  wire ROTp;               // debounced ROTpressed
  reg [1:0] MODE = 2'b00;    // state of LCD display, 0 = normal, 1 = original (with respect to modulation wheel)

  wire cfg;                       // This is for sensing an external 1 or 0 indicating whether the rotary encoder is backwards or not.
  
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
  wire rx1ready_status;
  wire reset_rx1ready_status;

  wire resetsignal;
// mcu
  wire read_strobe;
  wire write_strobe;

///////////////////////////////////////////////////////////////////////////////////////
// Synth signals

  reg [S-1:0] MCU_GATE = 0;
  reg [6:0] SYSEX_ADDR_MSB = 7'h00;

// Output values from processing of MIDI data.
  reg [6:0] MOD_WHL = 7'd64;                      // a usable initial value
  
  reg SUSTAIN = 1'b0;
  
  reg [6:0] VEL[S-1:0];               // dist RAM
  reg [6:0] NOTE[S-1:0];              // dist RAM

  reg [6:0] TRANSPOSE = 7'd36;              // global transposition in half steps.  The MIDI controller reads
                                            // this value and subtracts it from all note on message note numbers.
                                            // The synth hardware sees this adjusted value.

  reg [2:0] STR;                            // used as string select

// register to remember which strings are vibrating.  This is because the MIDI controller
// is programmed to show the true state of each key, only held keys have GATE high.
// But because of the sustain pedal, a string can be vibrating even if GATE is low.
// This register contains one bit per string.  The bit is set when the string is plucked
// and reset when the string is squelched.  This register is made available to the MCU
// for controlling voice assignment.
  reg [7:0] ACTIVE = 8'b00000000;

  reg [6:0] N;              // state machine NOTE working register
  reg [6:0] V;              // state machine VEL working register
  
//  reg [7:0] MCULED;                         // DIAGNOSTICS

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
    .reset(proc_reset|reset), .clk(clk) );  

  midictrl PSM_ROM0 ( .address(address), .instruction(instruction), .proc_reset(proc_reset), .clk(clk) );
  
  // MIDI receiver.  31,250 Baud
  assign resetsignal = write_strobe && ( port_id == 8'hFF );  // When port_id == FF with write strobe, reset the UARTs
  assign MIDI_In = Raw_MIDI_In;                    // Don't invert the MIDI serial stream for 6N138
  // assign MIDI_In = ~Raw_MIDI_In;                // Invert the MIDI serial stream

///////////////////////////////////////////////////////////////////////////////////////
// MIDI UART
// UART code by Jim Patchell
  MIDIuartrx UARTrx0 ( .dout(rx0data), .clk(clk), .reset(resetsignal), .rxd(MIDI_In), 
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
// UART code by Jim Patchell
  TTYuartrx UARTrx1 ( .dout(rx1data), .clk(clk), .reset(resetsignal), .rxd(TTY_In), 
    .frame(), .overrun(), .ready(), .busy(), .CS(), 
    .interrupt(interrupt1), .interrupt_ack(interrupt_ack), 
    .rxready_status(rx1ready_status), 
    .reset_rxready_status(reset_rx1ready_status)
    );
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////
  // decode read port 08, send pulse to reset rxready flop
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata.
  assign reset_rx1ready_status = (read_strobe == 1'b1) & (port_id == 8'h08);

// common interrupt signal for both serial ports.
  assign interrupt = (interrupt0 | interrupt1);  // ISR gets to figure out which UART did it.

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DAC - This DAC version accepts value 'cycles' which determines the amount of time between enables.

  reg [11:0] DACreg = 12'b100000000000;    // Data for SPI DAC
  wire [11:0] DACbus;

  reg [11:0] totalcycles = DACTIME;
  
// DAC, module by Eric Brombaugh
  spi_dac_out DAC (.clk(clk),.reset(reset),
                   .spi_sck(spi_sck),.spi_sdo(spi_sdi),.spi_dac_cs(spi_dac_cs),
                   .ena_out( DACena ),.data_in( DACreg ),
                   .cycles( totalcycles ) );

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// This ROM provides tuning, delivers length value for MIDI note number.

  reg  [10:0] WGlen;                   // holds string's length for state machine
  wire [10:0] WGlenROM;

  tun TUN ( .O( WGlenROM ), .A( N[5:0] ) );        // tuning ROM to translate MIDI note numbers to waveguide length
  
//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//== 
//==//==//==//==//==//==//  WAVEGUIDE RAM   //==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==
//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//== 
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// String RAMs (delay lines)

  reg [17:0]  wgRAM [16383:0];              // BLOCK RAM   waveguide RAM.  Holds 8 waveguides.  Upper 3 address bits select the waveguide
  reg [10:0]  SDLadr[S-1:0];                // dist RAM    address register for each string.  Upper 3 address bits select the waveguide
  reg [17:0]  SDLin = 18'h0000;             // register holds data for next RAM write
  reg [17:0]  SDLout;                       // RAM output
  wire [13:0] addr;
  reg [10:0]  WGadr;                        // state machine waveguide address register
  reg RAMWRT = 1'b0;
  
  assign addr = {STR,WGadr};

  always @ ( posedge clk )
    begin
    if ( RAMWRT ) wgRAM[addr] <= SDLin;    // write RAM on any FFCLR signal
    SDLout <= wgRAM[addr];
    end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Reflection point filter -  a single filter is shared between all 8 strings.
  reg                IIRena = 1'b0;
  reg  signed [17:0] IIRin;          // IIR0in is input register for IIR0, also serves as string loop output
  wire signed [17:0] IIRout;         // output of filter
  wire        [35:0] Delay;          // filter's delay value
  reg         [35:0] BW;             // bandwidth

  // Sign extend IIRin as IIRinX
  wire signed [21:0] IIRinX;
  
  assign IIRinX = {IIRin[17],IIRin[17],IIRin[17],IIRin[17],IIRin};

  assign Delay = 36'h7FFFFFFFF - BW ;

  IIRnew IIR ( .clk(clk), .ena(IIRena), .I(IIRin), .DEL(Delay), .SEL(STR), .O(IIRout) );
	 
/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
// Comb Filter Delay Line RAMs
// input to the filter is .I, the RAM input.

  wire        [17:0]  CFDLout;            // comb filter delay line RAM output

  reg         [7:0]   CFDLadr[S-1:0];     // dist RAM  CFDL address register 8 bits (256x18 RAM) per string
  reg         [7:0]   CFadr = 8'h00;      // register holds CFDLadr for state machine
  reg         [7:0]   CFlen = 8'h00;      // state machine CF length register

  DL2048 CFDL ( .A({STR,CFadr}), .I(IIRin), .O(CFDLout), .WRT(RAMWRT), .clk(clk) );
  
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Gate change detection objects:
  reg [S-1:0] old_GATE = 0;
  wire [S-1:0] GATEchgd;

///////////////////////////////////////////////////////////////////////////////
// for EXval:
  reg signed [17:0] EXval[S-1:0];   // dist RAM  waveguide EXval (excitation value) signal;
  reg signed [17:0] EXvaltmp;       // temp reg for computing EXval[] per string
  reg [S-1:0] EX = 1'b0;            // flag - hi = excite active
  reg [12:0] EXcnt[S-1:0];          // dist RAM  EXval pulse width counter
  reg [12:0] EXcnttmp;              // temp reg for computing EXcnt[] per string
  

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Waveguide state machine

  reg [2:0] state = 3'b000;
  reg run = 1'b0;

  reg [S-1:0] sign;              // used to invert sign for each excite to prevent "charging" the system.

  reg [21:0] CFsum = 22'h000000;
  assign DACbus = ( CFsum >>> 10 ) + 12'b100000000000 ;      // Output from comb filter sum

// / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / 

  wire [S-1:0] pluck;                          // what the pluck?  This is a string synth...

  reg  [S-1:0] FFCLR = 0;                      // pluck flipflop clears

  assign GATEchgd = MCU_GATE ^ old_GATE;       // true whenever gate signal changes state.

  wire signed [17:0] WGin;                       // Waveguide inputs
  assign WGin = ( sign[STR] == 1'b1 ) ? (-IIRout + EXval[STR]) : (-IIRout - EXval[STR]) ;

// squelch slow down:
  parameter sq_cnt_MAX = 5;  // number of samples between halving output
  reg [5:0] sq_cnt = 0;

// overflow detection:
  wire oflo;
  assign oflo = (( EXvaltmp[17] ^ IIRout[17] ) & ( WGin[17] ^ EXvaltmp[17] ));

//  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  
// state machine structure:

  always @ ( posedge clk )
    begin
    if ( DACena )
      begin
      state <= 3'h0;                            // starting state
      run <= 1'b1;                              // tell state machine to run
      STR <= 3'b000;                            // Select string zero to start
      DACreg <= DACbus;                         // write current DACbus value to DACreg for output
      CFsum <= 22'h000000;                      // reset output sum
      old_GATE <= MCU_GATE;                     // snapshot MCU_GATE for detecting a gate change
      // squelching counter
      if ( sq_cnt == sq_cnt_MAX ) sq_cnt <= 0;
      else                        sq_cnt <= sq_cnt + 1;
      end
    
    else        // else if NOT DACena:
      
      begin
		
      if ( MCU_GATE[0] == 1'b0 ) old_GATE[0] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[1] == 1'b0 ) old_GATE[1] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[2] == 1'b0 ) old_GATE[2] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[3] == 1'b0 ) old_GATE[3] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[4] == 1'b0 ) old_GATE[4] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[5] == 1'b0 ) old_GATE[5] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[6] == 1'b0 ) old_GATE[6] <= 1'b0;  // after DACena, only turn off if gate is off
      if ( MCU_GATE[7] == 1'b0 ) old_GATE[7] <= 1'b0;  // after DACena, only turn off if gate is off
		
      if ( run )
        begin
        case ( state ) 
        
        3'h0:                        // initialize for this string
          begin  state <= 3'h1;
          N <= NOTE[STR];            // get note value to N register from NOTE RAM
          V <= VEL[STR];             // get vel value to V register from VEL RAM
          WGadr <= SDLadr[STR];      // set waveguide address
          CFadr <= CFDLadr[STR];     // set comb filter address
          end

        3'h1:                        
          begin  state <= 3'h2;
          if ( SW[3] == 1'b1 ) BW <= {1'b0,ROTval,20'h00000} + ((N + 8) << 28);  // good for strings
          else                 BW <= {1'b0,ROTval,20'h00000} + ((N + 16) << 25);   // good for tonal drums, set encoder very low
          end

        3'h2:
          begin  state <= 3'h3;
          WGlen <= WGlenROM ;         // tunADR is now stable, get waveguide length for this string
          IIRin <= SDLout;            // transfer current string waveguide output to IIR input register
          IIRena <= 1'b1;             // tell filter to go, takes 3 clocks          
          end

        3'h3:                         // filter cycle 1 complete
          begin  state <= 3'h4;

          IIRena <= 1'b0;             // deassert the filter go flag
          
          EXvaltmp <= EXval[STR];    // sets default value for EXvaltmp in case next state's logic doesn't change it.
          EXcnttmp <= EXcnt[STR];

          case ( MODE )
          2'd0:
            begin
            case ( MOD_WHL[6:4] )            // keyboard to pickup position following
              3'b000: CFlen <= {1'b0,WGlen[10:4]};
              3'b001: CFlen <= {2'b01,WGlen[10:5]};
              3'b010: CFlen <= WGlen[10:3];
              3'b011: CFlen <= {2'b10,WGlen[10:5]};
              3'b100: CFlen <= {1'b1,WGlen[10:4]} ;
              3'b101: CFlen <= {2'b11,WGlen[10:5]};
              3'b110: CFlen <= {3'b111,WGlen[10:6]};
              3'b111: CFlen <= {4'b1111,WGlen[10:7]};
            endcase
            end
          2'd1:
            begin
            CFlen <= MOD_WHL << 1;     // simple flat approach, no key follow. (the "original" method)
            end
          2'd2:
            begin
            totalcycles <= ROTval[12:1] + DACTIME ;
            CFlen <= MOD_WHL << 1;     // simple flat approach, no key follow. (the "original" method)
            end
          2'd3:
            begin
            CFlen <= MOD_WHL << 1;     // simple flat approach, no key follow. (the "original" method)
            end            
          endcase

          end

        3'h4:                         // filter cycle 2 complete
          begin  state <= 3'h5;

          // This code generates either saw or pulse depending on SW[2].  0 - pulse, 1 - saw
          if ( pluck[STR] == 1'b1 )
            begin          
            ACTIVE[STR] <= 1'b1;                            // turn on ACTIVE flag for this string
            EX[STR] <= 1'b1;                                // turn on flag excite to start pulse
            sign[STR] <= ~sign[STR];                        // alternates which way the excite signal is signed.
            
            if ( SW[2] == 1'b0 )   // rect pulse
              begin
              EXcnttmp <= {2'b00,WGlen[10:0]} ;
              EXvaltmp <= ( ( V << 10 ) + 18'h003FF ) ;
              end
            else                   // saw pulse
              begin
              EXvaltmp <= 18'h00000 ;
              end
            end

          else        // else if NOT pluck:

            begin
            if ( EX[STR] == 1'b1 )        // if this string is currently being excited:
              begin
              if ( SW[2] == 1'b0 ) EXcnttmp <= EXcnttmp - 13'h0001;        // for rectangular pulse
              else                 EXvaltmp <= EXvaltmp + 18'sh00200 ;     // for ramp, generate ramp

              if ( ( EXcnttmp == 13'h0000 && SW[2] == 1'b0 ) || ( EXvaltmp >= 18'sh1FC00 && SW[2] == 1'b1 ) )
                begin
                EXvaltmp <= 18'h00000;                  // return value to zero
                EX[STR] <= 1'b0;                        // turn off flag excite to end pulse
                end
              end
            end
          end

        3'h5:                         // filter cycle 3 complete.  IIRout and WGin are valid
          begin  state <= 3'h6; 
          EXval[STR] <= EXvaltmp;     // save exciter values
          EXcnt[STR] <= EXcnttmp;

          if ( SUSTAIN == 1'b0 && MCU_GATE[STR] == 1'b0 )
            begin
            ACTIVE[STR] <= 1'b0;
            if ( sq_cnt == 0 )      SDLin <= WGin ;
            else                    SDLin <= WGin >>> 1 ;
            end
          else
            begin
            if ( oflo == 1'b0 )     // No oflo, just transfer WGin to SDLin
              begin
              SDLin <= WGin ;
              end
            else                    // OFLO: apply clipping
              begin
              if ( sign[STR] == 1'b1 ) SDLin <= 18'h1FFFF ; // use positive maximum
              else                     SDLin <= 18'h20001 ; // use negative maximum          
              end              
            end

          CFsum <= CFsum + (IIRinX - {CFDLout[17],CFDLout[17],CFDLout[17],CFDLout[17],CFDLout});
 
          RAMWRT <= 1'b1;                     // set waveguide RAM write enable
          FFCLR[STR] <= 1'b1;                               
          
          end

        3'h6:
		      begin  state <= 3'h0;               // set state to start of string process

          RAMWRT <= 1'b0;                     // reset waveguide RAM write enable
          FFCLR[STR] <= 1'b0;                               

          SDLadr[STR] <= ( (WGadr + 1) < WGlen ) ? (WGadr + 1) : 11'h000 ;
          CFDLadr[STR] <= ( (CFadr + 1) < CFlen ) ? (CFadr + 1) : 8'h00 ;          

          if ( STR == S-1 ) run <= 1'b0;      // stop the state machine after all strings are processed
          
          STR <= STR + 1;                     // select next string
          end

        endcase
        end
      end
    end  

// "pluck" flip flops.  These RS flip flops are set when a gate has changed from 0 to 1.
// all flops are reset at their string's RAM write time.
  wire [S-1:0] SETp;
  assign SETp = GATEchgd & MCU_GATE;
  FDCPE #(.INIT(1'b0)) RSFF0 (.Q(pluck[0]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[0]),.D(1'b0),.PRE(SETp[0]));
  FDCPE #(.INIT(1'b0)) RSFF1 (.Q(pluck[1]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[1]),.D(1'b0),.PRE(SETp[1]));
  FDCPE #(.INIT(1'b0)) RSFF2 (.Q(pluck[2]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[2]),.D(1'b0),.PRE(SETp[2]));
  FDCPE #(.INIT(1'b0)) RSFF3 (.Q(pluck[3]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[3]),.D(1'b0),.PRE(SETp[3]));
  FDCPE #(.INIT(1'b0)) RSFF4 (.Q(pluck[4]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[4]),.D(1'b0),.PRE(SETp[4]));
  FDCPE #(.INIT(1'b0)) RSFF5 (.Q(pluck[5]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[5]),.D(1'b0),.PRE(SETp[5]));
  FDCPE #(.INIT(1'b0)) RSFF6 (.Q(pluck[6]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[6]),.D(1'b0),.PRE(SETp[6]));
  FDCPE #(.INIT(1'b0)) RSFF7 (.Q(pluck[7]),.C(1'b0),.CE(1'b0),.CLR(FFCLR[7]),.D(1'b0),.PRE(SETp[7]));

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Rotary Encoder

  wire ROTev;   // rotary press event
  wire ROTevCLR;
  
  ROTv3 ROT (.clk(clk),.ROTa(ROTa),.ROTb(ROTb),.value_out(ROTval),.BTN_W(BTN_W),.reset(reset),.cfg(cfg));
  
  debounce DBNC ( .clk(clk), .I(ROTpress), .O(ROTp) );

  assign ROTevCLR = (read_strobe == 1'b1) & (port_id == 8'h09);

// this FF sets when you press the rotary button.  It is cleared when the MCU reads port 09
  FDCPE #(.INIT(1'b0)) RSFF8 (.Q(ROTev),.C(1'b0),.CE(1'b0),.CLR(ROTevCLR),.D(1'b0),.PRE(ROTp));
  
  always @ ( posedge ROTp ) MODE <= MODE + 1;

///////////////////////////////////////////////////////////////////////////////  
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////  
// Decode structures for hardware receiving data from the MCU

  always @ ( posedge clk )
    begin
    if ( write_strobe == 1'b1 )
      begin
// This case block contains selection logic for system level ports and for CC ports.
// Note that these ports all have  bit 7 of port_id set.
      casex ( port_id )
        8'b10100xxx: VEL[port_id[2:0]]  <= out_port[6:0];   // addresses all 8 velocity ports
        8'b10101xxx: NOTE[port_id[2:0]] <= out_port[6:0];   // addresses all 8 note number ports
        8'h90: LCD <= out_port;
        8'hE0: SYSEX_ADDR_MSB <= out_port;
        8'hF3: MOD_WHL     <= out_port[6:0];    // modulation wheel, global
        8'hF7: SUSTAIN     <= out_port[6];      // SUSTAIN pedal
        8'hF8: MCU_GATE    <= out_port[S-1:0];  // MCU_GATE signal, per voice.
   
//        8'hFE: MCULED      <= out_port;
//      8'hFF: reset both UARTs.  See area of instantiation of UARTs    

      endcase
      end
    end

// make sure that in_port_reg always contains selected data at rising edge of clk,
// PicoBlaze will read it when it needs it.
  always @ ( posedge clk ) 
    begin
    case ( port_id[3:0] )                        // decode and transfer data to in_port_reg
      4'h0: in_port_reg <= {rx1ready_status,rx0ready_status,6'b000000}; // UART1 & UART0 rxready bits
      4'h1: in_port_reg <= rx0data;                   // MIDI UART rxdata
      4'h2: in_port_reg <= {6'b000000,SW[1:0]};       // slide switches, 2 used to select MIDI chan 1-4.
      4'h7: in_port_reg <= {1'b0,TRANSPOSE};
      4'h8: in_port_reg <= rx1data;                   // TTY UART rxdata
      4'h9: in_port_reg <= {ROTev,5'b00000,MODE};
      4'hA: in_port_reg <= ACTIVE;                    // vibrational state of each string
      default: in_port_reg <= 8'bxxxxxxxx;
    endcase
    end

/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
// LEDs

  // BTN_S = 1, show mod wheel upper 3 bits in rightmost 3 LEDs
  // BTN_S = 0, show ROTval

  assign led = (BTN_S == 1'b1) ? {5'b00000,MOD_WHL[6:4]} : ROTval[14:7];     // DEFAULT CONFIG: nice to know the BW value...

// // // // // // // // // // // // // // // // // // // // // // // // // // // // // // // 

// DIAGNOSTIC:
//  assign led = MCU_GATE;
//  assign led = ACTIVE;
//  assign led = MCULED;

//assign led = {7'h00, oflo};

endmodule
