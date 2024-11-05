`timescale 1ns / 1ps
// Engineer: Scott R. Gravenhorst
// email: music.maker@gte.net
// Date Started: 2007-01-13
// Design Name:
// Description:
//
// ver_a: First cut
//
// ver_b: Proof of concept, 4 NCOs - works, sample rate 250 KHz
//
// ver_c: Changed address space to accomodate 32 NCOs.
//        Push to 32 NCOs.
//
// ver_d: Clean up minor issues, remove proc_reset wire.
//        The timing report shows that the NzIIR filter is quite slow and causes the timing
//        to almost violate the constraint.  Since this is just a noise timer, there is no reason
//        that it's output should be calculated before it is needed.  In this version, the output
//        is acquired before the enable but after sel has been set.  The calculation is then started
//        by asserting ena after the output has been captured.  This will allow us to change NZIIR
//        to use 2 clocks instead of one without adding another state to NCO_mult's state machine.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

// The slide switches provide MIDI channel configuration.  
// Switches should be set to MIDI_channel - 1 in binary.  The switches are sampled whenever a complete
// MIDI message is received so the effect of the switches is immediate.

// MIDI System Exclusive Message structure:
// MFR ID
// MODEL NUMBER
// UNIT NUMBER
// PARAMETER ADDRESS MSB
// PARAMETER ADDRESS LSB
// PARAMETER DATA

module sine_synth ( clk, led, lcd_rs, lcd_rw, lcd_e, lcd_d, ROTa, ROTb, ROTpress,
                   BTN_EAST, BTN_WEST, BTN_SOUTH,
                   spi_sck, spi_dac_cs, spi_sdi, spi_rom_cs, spi_amp_cs, spi_adc_conv, spi_dac_cs, spi_amp_shdn, spi_dac_clr,
                   strataflash_oe, strataflash_ce, strataflash_we, platformflash_oe,
                   switch, Raw_MIDI_In, TTY_In );

/////////////////////////////////////////////////////////////////////////////////////////
// This parameter supplies the version number to an MCU port which is displayed in the LCD.
////////////////////////////////////////////////////////////////////////////////////////
                              //                                                      //
                              //     #     #  #####  ####    ###   ###   ###   #   #  //
                              //     #     #  #      #   #  #       #   #   #  ##  #  //
  parameter version = "d";    //      #   #   ###    ####    ###    #   #   #  # # #  //
                              //       # #    #      #  #       #   #   #   #  #  ##  //
                              //        #     #####  #   #   ###   ###   ###   #   #  //
                              //                                                      //
////////////////////////////////////////////////////////////////////////////////////////

  parameter NCOs = 32;
  parameter NCOMAX = NCOs - 1;
  parameter SEL_WIDTH = 5;       // 2 raised to this value should equal the value of NCOs.

  parameter SRdiv = 4;           // sample rate divider.  8 = 125 KHz, 4 = 250 KHz, 2 = 500 KHz, 1 = 1 MHz
  parameter SRdiv1 = SRdiv - 1;  // used in sample rate divider always block
  

  input clk;
  output [7:0] led;
  
  inout [7:4] lcd_d;
  output lcd_rs;
  output lcd_rw;
  output lcd_e;
  
  input ROTa;
  input ROTb;
  input ROTpress;
  
  input BTN_EAST;     // MCU reset
  input BTN_WEST;     // master tune multiplier, when pushed, causes increment of 16 instead of 1.
  input BTN_SOUTH;    // select LEDs to monitor MCU_GATE and MIDI raw input OR NCOled (noise output before shifter)
  
  output spi_sck;
  output spi_sdi;
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

  wire [SEL_WIDTH-1:0] sel;             // NCO select, driven by NCO state machine
  wire [SEL_WIDTH-1:0] sel4;            // NCO select, driven by NCO state machine
  wire [SEL_WIDTH-1:0] sel5;            // NCO select, driven by NCO state machine

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

  wire clk;
  wire [7:0] led;
  wire [2:0] ledF;

  wire [14:0] ROTout;      // output from rotary encoder's register
  
//  wire DACena;

  wire BTN_EAST, BTN_WEST;

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
  reg [7:0] in_port_reg;          // hold data for mcu
  assign in_port = in_port_reg;

// MIDI & TTY UART receivers
  wire [7:0] rx0data;
  wire rx0ready_status;
  wire reset_rx0ready_status;
  
  wire [7:0] rx1data;
  wire reset_rx1ready_status;

  wire resetsignal;
// MCU
  wire read_strobe;
  wire write_strobe;

// output vectors
  wire [11:0] DACbus;

// Synth signals

  reg [6:0] SYSEX_ADDR_MSB = 7'h00;

  reg [3:0] MIDI_CHANNEL = 0;
// hardware ports that mcu writes to
// 8 bit:
  reg [7:0] NOTENUM;            // MIDI note number, used as a modulation source

// 7 bit:  (these are supplied by sysex messages, thus are restricted to 7 bits.
// 14 bit values are assembled in hardware.
  reg [13:0] PW = 14'b10000000000000;  // init pitch wheel at center in case it never sends a message
//  reg [6:0] CHANpres;
  reg [6:0] MOD_WHL;
  reg [6:0] VEL;
  reg [6:0] TRANSPOSE = 7'h00;          // global transposition in half steps
  reg       MCU_GATE = 1'b0;
  reg       SUSTAIN = 1'b0;

  reg [7:0] NOTEOCT;                    // port register to receive note-octave information from MCU

  reg [4:0] NZbw       [NCOMAX:0];      //  DIST. RAM - Noise bandwidth value for each NCO
  reg [6:0] FINTUNhi   [NCOMAX:0];      //  DIST. RAM - fine tune registers
  reg [6:0] FINTUNlo   [NCOMAX:0];      //  DIST. RAM
  reg [6:0] LEVhi      [NCOMAX:0];      //  DIST. RAM - level value MSB
  reg [6:0] LEVlo      [NCOMAX:0];      //  DIST. RAM - level value LSB
  reg [5:0] harmonic   [NCOMAX:0];      //  DIST. RAM - harmonic phase increment multiplier
  reg [6:0] PRTtimhi   [NCOMAX:0];      //  DIST. RAM - portamento time MSB
  reg [6:0] PRTtimlo   [NCOMAX:0];      //  DIST. RAM - portamento time LSB
  reg [6:0] NZgenLevhi [NCOMAX:0];      //  DIST. RAM - noise filter modulation level MSB
  reg [6:0] NZgenLevlo [NCOMAX:0];      //  DIST. RAM - noise filter modulation level LSB
  
///////////////////////////////////////////////////////////////////////////////////////  

  reg [13:0] NCFadsrA;
  reg [13:0] NCFadsrD;
  reg [13:0] NCFadsrS;
  reg [13:0] NCFadsrR;
  reg [13:0] NCFpk;                // peak config value
  reg [13:0] NCFmin;               // min config value

///////////////////////////////////////////////////////////////////////////////////////  

  reg [13:0] NCAadsrA;
  reg [13:0] NCAadsrD;
  reg [13:0] NCAadsrS;
  reg [13:0] NCAadsrR;
  
///////////////////////////////////////////////////////////////////////////////////////  

  reg [1:0] NCFpkMDsrc;
  reg [1:0] NCFsusMDsrc;
  
///////////////////////////////////////////////////////////////////////////////////////  

  reg [1:0] NCApkMDsrc;
  reg [1:0] NCAsusMDsrc;

///////////////////////////////////////////////////////////////////////////////////////  

//  reg [7:0] MCU_LED;          // for diagnostics
//  reg [7:0] led_reg;          // For diagnostics

///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
// POR delay FF chain - taken from Eric Brombaugh's code for the SPI DAC.
  FDCE rst_bit0 (.Q(rstd[0]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(1'b1));
  FDCE rst_bit1 (.Q(rstd[1]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[0]));
  FDCE rst_bit2 (.Q(rstd[2]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[1]));
  FDCE rst_bit3 (.Q(rstd[3]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[2]));
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
///////////////////////////////////////////////////////////////////////////////////////
// instantiate the uC (kcpsm3) with it's ROM

  kcpsm3 MCU ( .address(address), .instruction(instruction), .port_id(port_id), 
    .write_strobe(write_strobe), .out_port(out_port), .read_strobe(read_strobe), .in_port(in_port), 
    .interrupt(interrupt), .interrupt_ack(interrupt_ack), 
    .reset(reset), .clk(clk) );  

  midictrl PSMROM ( .address(address), .instruction(instruction), .clk(clk) );
  
  // MIDI receiver.  31,250 Baud
  assign resetsignal = write_strobe && ( port_id == 8'hFF );  // When port_id == FF with write strobe, reset the UARTs
  assign MIDI_In = Raw_MIDI_In;                    // Don't invert the MIDI serial stream for 6N138
  // assign MIDI_In = ~Raw_MIDI_In;                // Invert the MIDI serial stream

///////////////////////////////////////////////////////////////////////////////////////
// MIDI UART
  MIDIuartrx RX0 ( .dout(rx0data), .clk(clk), .reset(resetsignal), .rxd(MIDI_In), 
    .frame(), .overrun(), .ready(), .busy(), .CS(), 
    .interrupt(interrupt0), .interrupt_ack(interrupt_ack), 
    .rxready_status(rx0ready_status), 
    .reset_rxready_status(reset_rx0ready_status)
    );
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////
  // decode read port 01, send pulse to reset rxready flop
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata.
  assign reset_rx0ready_status = (read_strobe == 1'b1) & (port_id[3:0] == 4'h1);

///////////////////////////////////////////////////////////////////////////////////////
// TTY UART, 115.2 or 19.2 kilobuad (baudrate configured in module)
  TTYuartrx RX1 ( .dout(rx1data), .clk(clk), .reset(resetsignal), .rxd(TTY_In), 
    .frame(), .overrun(), .ready(), .busy(), .CS(), 
    .interrupt(interrupt1), .interrupt_ack(interrupt_ack), 
    .rxready_status(rx1ready_status), 
    .reset_rxready_status(reset_rx1ready_status)
    );
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////
  // decode read port 09, send pulse to reset rxready flop
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata.
  assign reset_rx1ready_status = (read_strobe == 1'b1) & (port_id[3:0] == 4'h9);

// common
  assign interrupt = (interrupt0 | interrupt1);  // ISR gets to figure out which UART did it.

///////////////////////////////////////////////////////////////////////////////
// Synth component interconnection objects:

  wire gate;                     // state of gate is maintained by kcpsm3

  wire signed [35:0] NCAout;
  wire signed [17:0] NCA_ctrl;

// NCF:
  wire signed [17:0] freq;
  wire signed [17:0] FILout;

// NCF ADSR:
  wire signed [17:0] NCFadsrRAW;

// NCO output bus
  wire signed [17:0] NCOout;          // for multi NCO module
  
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DAC Timing
// The following logic divides the ena_out signal from the spi_dac_out
// module by N and preserves the original pulse width in the output DACena signal.
//
// Hook to DACena for 250000 samples per second.

//  reg [11:0] DACreg = 12'b100000000000;    // Data for SPI DAC
//  wire [11:0] DACbus;
  wire ena_out;

  reg [2:0] DACcnt = 3'b000;
  reg DACena = 1'b0;
  
  always @ ( posedge clk )
    begin
    if ( ena_out == 1'b1 )
      begin
      if ( DACcnt < SRdiv1 ) DACcnt <= DACcnt + 3'b001;
      else                  
        begin 
        DACena <= 1'b1; 
        DACcnt <= 3'b000; 
        end
      end   
    else DACena <= 1'b0 ;
    end

// DAC, module by Eric Brombaugh
  spi_dac_out DAC (.clk( clk ),.reset( reset ),
                   .spi_sck( spi_sck ),.spi_sdo( spi_sdi ),.spi_dac_cs( spi_dac_cs ),
                   .ena_out( ena_out ),.data_in( DACreg ));

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Sustain pedal logic

  reg SUS = 1'b0;
  assign gate = MCU_GATE | SUS;             // single bit

  always @ ( posedge clk )
    begin
    case ( SUSTAIN )                        // SUSTAIN is a single bit representing the sustain pedal state
      1'b0: SUS <= 1'b0;                    // if pedal is up, always clear SUS
      1'b1: if ( MCU_GATE ) SUS <= 1'b1;    // if pedal is down, only set SUS on MCU_GATE high
    endcase
    end

///////////////////////////////////////////////////////////////////////////////
// multi NCO
  
  reg  [2:0] MIXERshifts = 3'h5;
  reg  [5:0] NoiseWindow = 1;
  wire [7:0] NCOled;

  nco_multi_f #( .NCOMAX( NCOMAX ), .SEL_WIDTH( SEL_WIDTH ) ) NCOmult (
    .out( NCOout ), 
    .sel0 ( sel ),                   // sel0 is an output driven by the NCO state machine
    .sel4 ( sel4 ),                  // sel4 is an output driven by the NCO state machine
    .sel5 ( sel5 ),                  // sel4 is an output driven by the NCO state machine
    .clk( clk ), 
    .ena( DACena ), 
    .reset( reset ), 
    .noteoct( NOTEOCT ),
    .finTUN( {FINTUNhi[sel],FINTUNlo[sel], 1'b0} ),
    .lev( {LEVhi[sel],LEVlo[sel]} ),
    .PRTtim( {4'h0,PRTtimhi[sel5],PRTtimlo[sel5]} ),
    .NZbw( NZbw[sel4] ),
    .NZgenLev( {NZgenLevhi[sel4],NZgenLevlo[sel4]} ),
    .TUNglob( ROTout ),
    .PW( PW ),
//    .CHANpres( CHANpres ),
    .MOD_WHL( MOD_WHL ),
    .VEL( VEL ),
    .harmonic( harmonic[sel] ),
    .MIXERshifts( MIXERshifts ),
    .NoiseWindow( NoiseWindow ),
    .NCOled(NCOled)
    );

///////////////////////////////////////////////////////////////////////////////
// Connect output (and convert signed arithmetic to unsigned DAC requirement)

  reg [5:0] DACwin = 6'd0;

  assign DACbus = ( NCAout >>> DACwin ) + 12'b100000000000 ;   
    
  always @ ( posedge clk ) if ( DACena ) DACreg <= DACbus;
  
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// NCA

  assign NCAout = FILout * NCA_ctrl;         // That's all there's too it.
  
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
// NCA ADSR

  wire [16:0] NCAsus;            // MUX out select MX0 or 
  wire [6:0] NCAsusMODMX;        // MUX out select pressure or velocity

  assign NCAsusMODMX = NCAsusMDsrc[0] ? MOD_WHL : VEL ;
  assign NCAsus      = NCAsusMDsrc[1] ? {NCAsusMODMX,10'b0000000000} : {NCAadsrS,3'h0} ;

  wire [2:0] ledA;

  NCAadsr NCAADSR  (
    .out( NCA_ctrl ),                // 18 bits
    .clk( clk ), 
    .ena( DACena ),
    .GATE( gate ), 
    .A( NCAadsrA ),                  // 14 bits
    .D( NCAadsrD ),                  // 14 bits
    .S( NCAsus ),                    // 17 bits
    .R( NCAadsrR ),                  // 14 bits
    .led( ledA )                     // state of ADSR
    );

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// NCF - A digital state variable filter with resonance.

  reg [13:0] qval;

  SVF SVF (
    .clk( clk ), 
    .ena( DACena ),                  // ena tells filter to "go"
    .f( freq ),                      // Filter corner frequency (NOT in Hz, but close)
    .q( {qval,4'b1111} ),            // Filter Q value
    .In( NCOout [17:6] ),            // signed 12 bit input
    .Out( FILout )                   // signed 18 bit output 
    );

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// NCF ADSR and it's modulation source selection:
//

  assign freq = NCFadsrRAW ;

// ncf ADSR peak value modulation
  wire [17:0] ncfPKmdSRC0;      // MUX output selecting mod wheel or velocity
  wire [17:0] ncfPKmdSRC1;      // MUX output selecting note number of peak config setting
  wire [17:0] ncfPKval;         // applied to ADSR, 4:1 MUX out

  assign ncfPKmdSRC0 = NCFpkMDsrc[0] ? {6'h00,MOD_WHL,5'h00} + 240 : {6'h00,VEL,5'h00} + 240 ;
  assign ncfPKmdSRC1 = NCFpkMDsrc[0] ? {3'h0,NCFpk,1'b0} : ({7'h00,NOTENUM,4'h0} + 240);
  assign ncfPKval    = NCFpkMDsrc[1] ? ncfPKmdSRC1 : ncfPKmdSRC0 ;
  
////////////////////////////////////////////////////////////////////////////////
// sustain level modulation
  wire [17:0] NCFsusmodMX0;     // MUX out select mod wheel or velocity
  wire [17:0] NCFsusmodMX1;     // MUX out select config value or note number
  wire [17:0] NCFsus;           // 4:1 MUX out

  assign NCFsusmodMX0 = NCFsusMDsrc[0] ? {7'h00,MOD_WHL,4'h0} + 80 : {7'h00,VEL,4'h0} + 120 ;
  assign NCFsusmodMX1 = NCFsusMDsrc[0] ? {4'h0,NCFadsrS} : ({9'h000,NOTENUM,2'h0} + 120) ;
  assign NCFsus       = NCFsusMDsrc[1] ? NCFsusmodMX1 : NCFsusmodMX0 ;
       
///////////////////////////////////////////////////////////////////////////////
// NCF ADSR instantiation

  NCFadsr NCFADSR (
    .out( NCFadsrRAW ),               // 18 bits
    .clk( clk ),
    .ena( DACena ),      
    .GATE( gate ), 
    .A( NCFadsrA ),                   // 14 bits
    .D( NCFadsrD ),                   // 14 bits
    .S( NCFsus ),                     // 18 bits
    .R( NCFadsrR ),                   // 14 bits
    .peak( ncfPKval ),                // 18 bits
    .minval( NCFmin ),                // 14 bits
    .led( ledF )                      // state of ADSR
    );
    
///////////////////////////////////////////////////////////////////////////////
// Rotary Encoder - special version for this project
//               
  RotaryEncoder_v2 ENC (.clk(clk),.ROTa(ROTa),.ROTb(ROTb),.ROTpress(ROTpress),.BTN_WEST(BTN_WEST),.value_out(ROTout),.ROTpress_out(ROTpress_out));

///////////////////////////////////////////////////////////////////////////////  
// Decode structures for hardware receiving data from the MCU

  always @ ( posedge clk )
  begin
    if ( write_strobe == 1'b1 )
    begin
// This case block contains selection logic for system level ports and for CC ports.
// Note that these ports all have the bit 7 or port_id set.
    casex ( port_id )
//    8'hF0:       CHANpres              <= out_port[6:0];  // channel pressure value, global
    8'hF1:       PW[13:7]              <= out_port[6:0];  // pitch wheel MSB, global
    8'hF2:       PW[6:0]               <= out_port[6:0];  // pitch wheel LSB, global
    8'hF3:       MOD_WHL               <= out_port[6:0];  // modulation wheel, global
    8'hF4:       NOTEOCT               <= out_port[7:0];  // F4 only
    8'hF8:       MCU_GATE              <= out_port[0];    // MCU_GATE signal
    8'hF9:       VEL                   <= out_port[6:0];  // port to set synth hardware velocity register
    8'hFC:       SUSTAIN               <= out_port[6];    // sustain command register
    
//    8'hFE: MCU_LED <= out_port;           // for diagnostics
//    8'hFF: reset both UARTs.  See area of instantiation of UARTs    

    8'hE0:       SYSEX_ADDR_MSB        <= out_port[6:0];
      
    8'hD0:       NOTENUM               <= out_port;       // this is used only as a modulation source
    
    8'h90:       LCD                   <= out_port;
    endcase
//////////////////////////////////////////////////////////////////////////////////////////
// These if blocks contain case blocks for sysex populated parameters     
// below this, all port_id values have bit 7 set to zero
// Address space is 14 bits.

    if ( SYSEX_ADDR_MSB == 7'h00 )
      begin
      case ( port_id )
      8'h10:       TRANSPOSE                       <= out_port[6:0];   // global transpose by semitones, neg values don't work - fix this
     
      8'h1E:       NCFadsrA[13:7]                  <= out_port[6:0];
      8'h1F:       NCFadsrA[6:0]                   <= out_port[6:0];
      8'h20:       NCFadsrD[13:7]                  <= out_port[6:0];
      8'h21:       NCFadsrD[6:0]                   <= out_port[6:0];
      8'h22:       NCFadsrS[13:7]                  <= out_port[6:0];
      8'h23:       NCFadsrS[6:0]                   <= out_port[6:0];
      8'h24:       NCFadsrR[13:7]                  <= out_port[6:0];
      8'h25:       NCFadsrR[6:0]                   <= out_port[6:0];
      8'h26:       NCFpk[13:7]                     <= out_port[6:0];
      8'h27:       NCFpk[6:0]                      <= out_port[6:0];
      8'h28:       NCFmin[13:7]                    <= out_port[6:0];
      8'h29:       NCFmin[6:0]                     <= out_port[6:0];

      8'h2A:       NCAadsrA[13:7]                  <= out_port[6:0];
      8'h2B:       NCAadsrA[6:0]                   <= out_port[6:0];
      8'h2C:       NCAadsrD[13:7]                  <= out_port[6:0];
      8'h2D:       NCAadsrD[6:0]                   <= out_port[6:0];
      8'h2E:       NCAadsrS[13:7]                  <= out_port[6:0];
      8'h2F:       NCAadsrS[6:0]                   <= out_port[6:0];
      8'h30:       NCAadsrR[13:7]                  <= out_port[6:0];
      8'h31:       NCAadsrR[6:0]                   <= out_port[6:0];
     
      8'h40:       NCFpkMDsrc                      <= out_port[1:0];
      8'h41:       NCFsusMDsrc                     <= out_port[1:0];
      
      8'h48:       NCApkMDsrc                      <= out_port[1:0];
      8'h49:       NCAsusMDsrc                     <= out_port[1:0];

      8'h60:       qval[13:7]                      <= out_port[6:0];
      8'h61:       qval[6:0]                       <= out_port[6:0];
       
      8'h62:       DACwin                          <= out_port[6:0];   // DAC window value
      8'h63:       MIXERshifts                     <= out_port[2:0];   // shouldn't be more than 5

      8'h64:       NoiseWindow                     <= out_port[5:0];
      endcase
      end
/////////////////////////////////////////////////////////////////////////////////////////////
// Use this for address space extension.  Each block created like this one must
// have a unique SYSEX_ADDR_MSB value which may not be larger than 127
     if ( SYSEX_ADDR_MSB == 7'h01 )
       begin
       casex ( port_id )
         8'b000xxxxx: LEVhi[port_id[4:0]]             <= out_port[6:0];   // 00 to 1F
         8'b001xxxxx: LEVlo[port_id[4:0]]             <= out_port[6:0];   // 20 to 3F
       endcase
       end       

     if ( SYSEX_ADDR_MSB == 7'h02 )
       begin
       casex ( port_id )
         8'b000xxxxx: harmonic[port_id[4:0]]          <= out_port[5:0];   // 00 to 1F
       endcase
       end       

     if ( SYSEX_ADDR_MSB == 7'h03 )
       begin
       casex ( port_id )
         8'b000xxxxx: FINTUNhi[port_id[4:0]]          <= out_port[6:0];   // 00 to 1F
         8'b001xxxxx: FINTUNlo[port_id[4:0]]          <= out_port[6:0];   // 20 to 3F
       endcase
       end       

     if ( SYSEX_ADDR_MSB == 7'h04 )
       begin
       casex ( port_id )
         8'b000xxxxx: NZgenLevhi[port_id[4:0]]        <= out_port[6:0];   // 00 to 1F
         8'b001xxxxx: NZgenLevlo[port_id[4:0]]        <= out_port[6:0];   // 20 to 3F
       endcase
       end       

     if ( SYSEX_ADDR_MSB == 7'h05 )
       begin
       casex ( port_id )
         8'b000xxxxx: NZbw[port_id[4:0]]              <= out_port[4:0];   // 00 to 1F
       endcase
       end       

     if ( SYSEX_ADDR_MSB == 7'h06 )
       begin
       casex ( port_id )
         8'b000xxxxx: PRTtimhi[port_id[4:0]]          <= out_port[6:0];   // 00 to 1F
         8'b001xxxxx: PRTtimlo[port_id[4:0]]          <= out_port[6:0];   // 20 to 3F
       endcase
       end       

     if ( SYSEX_ADDR_MSB == 7'h7F )
       begin
       case ( port_id )
         8'b00000000: MIDI_CHANNEL                    <= out_port[3:0];   // 00 to 1F
       endcase
       end       

    end
  end

// make sure that in_port_reg always contains selected data at rising edge of clk,
// PicoBlaze will read it when it needs it.
  always @ ( posedge clk ) 
    begin
    casex ( port_id[3:0] )                               // decode and transfer data to in_port_reg
    4'h0:    in_port_reg <= {rx1ready_status,rx0ready_status,6'b000000}; // UART1 & UART0 rxready bits
    4'h1:    in_port_reg <= rx0data;                     // MIDI UART rxdata
//    4'h2:    in_port_reg <= {4'b0000,switch};            // slide switches
    4'h2:    in_port_reg <= {4'b0000,MIDI_CHANNEL};            // slide switches

// in sine_synth, there is no offset required.
//    4'b01xx: in_port_reg <= {1'b0,CRSTUN[port_id[1:0]]}; // CRS pitch offset for NCO0 (half steps, signed) 04-07

    4'h8:    in_port_reg <= {1'b0,TRANSPOSE};
    4'h9:    in_port_reg <= rx1data;                     // TTY UART rxdata
    4'hF:    in_port_reg <= version;                     // The GateMan version number stored in hardware
    default: in_port_reg <= 8'bxxxxxxxx;
    endcase
    end

/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
// LEDs
// monitor both ADSR state values
//  assign led = {~Raw_MIDI_In,MCU_GATE,ledF,ledA} ;  
//  assign led = {~Raw_MIDI_In,MCU_GATE,2'b00,switch} ;

  assign led = (BTN_SOUTH) ? {~Raw_MIDI_In,MCU_GATE,2'b00,MIDI_CHANNEL} : NCOled ;

/////////////////////////////////////////////////////////////////////////////////////////////

endmodule
