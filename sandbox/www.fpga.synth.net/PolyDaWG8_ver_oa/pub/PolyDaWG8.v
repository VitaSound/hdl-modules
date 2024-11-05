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
// Sample Rate: 250 KHz (nominal for S-3Esk 12 bit DAC).
// Sample Rate: 200 KHz (nominal for Avnet board and CS4344 DAC)
// 
// S-3Esk:
// Variable sample rate from 92 clocks per sample (rate: 543,478.26/Sec) down to
//   a maximum of 4095 (rate: 12,210.01/Sec).  Note that this low sample rate is not
//   sonically useful.
//
// S-3A Avnet with CS4344:
// Sample rate is fixed at 200 KHz, the maximum for this DAC.  192 system clocks per 
// enable.  Tuning ROM set to start on G (MIDI # 19).  The lowest 5 keys will make no 
// sound.  48 notes are available (4 octaves) at better than 5 cents pitch accuracy.
//
//////////////////////////////////////////////////////////////////////////////////////
//
//                                PUSH BUTTON CONTROLS, LEDS and CONNECTIONS:
//
//    PUSH_A - increase filter bandwidth
//    PUSH_B - decrease filter bandwidth
//    PUSH_C - no function
//
//    LEDs normally show the top 4 bits of 13 bit register ROTval (controls filter bandwidth).
//
//    J6 - MIDI Input
//    J7 - I2S DAC (Cirrus CS4344)
//
//////////////////////////////////////////////////////////////////////////////////////
//
// Old comments redacted, see ver_o verilog file from S-3Esk
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  ADAPTED FOR $39 AVNET BOARD WITH SPARTAN-3A 400K GATE FPGA and Cirrus CS4344 DAC.
//
// ver_oa:  This is the first cut at porting from S-3Esk to the Avnet Spartan-3A 400 board with MIDI and DAC
//          addon hardware.
//
// The DAC (CS4344) operates up to 200 KHz.  This is done with a 38.4 MHz MCLK and a divide ratio of 192.
// 192 clocks will probably be sufficient even if we upsample to raise pitch.  One state machine pass requires
// 92 clocks, thus 2:1 upsampling is possible.
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
module PolyDaWG8( CLK_16MHZ, led, PUSH_RESET, PUSH_A, PUSH_B, PUSH_C, DIGI1, DIGI2 );

  parameter S = 8;               // set the total number of strings

  input CLK_16MHZ;
  output [3:0] led;
  input PUSH_A;
  input PUSH_B;  
  input PUSH_C;  
  input PUSH_RESET;  
  output [3:0] DIGI1;    // J7 - I2S DAC
  input  [3:0] DIGI2;    // J6 - MIDI         
    
//////////////////////////////////////////////////////////////////////////////////////
  wire PUSH_A;
  wire PUSH_B;
  wire PUSH_C;
  wire PUSH_RESET;
//////////////////////////////////////////////////////////////////////////////////////
  wire Raw_MIDI_In;
  assign Raw_MIDI_In = DIGI2[3];   // from pin G1, board socket J6
//////////////////////////////////////////////////////////////////////////////////////
  wire CLK_16MHZ;                 // hardware xtal clock, fed only to DAC
  wire [3:0] rstd;                // POR delay
  wire reset;                     // POR/User reset
//////////////////////////////////////////////////////////////////////////////////////
  wire clk;    // our system clock and DAC MCLK, 38.4 MHz
  DCM_38_4 DCM ( .CLKIN_IN( CLK_16MHZ ), .RST_IN( 1'b0 ), .CLKFX_OUT(  clk ), .CLKIN_IBUFG_OUT(), .CLK0_OUT(), .LOCKED_OUT() );
//////////////////////////////////////////////////////////////////////////////////////
  wire interrupt;
  wire interrupt_ack;
  wire interrupt0;
  wire [9:0] address;             // wires to connect address lines from uC to ROM
  wire [17:0] instruction;        // uC data lines, need connection between uC and ROM
  wire [7:0] out_port;            //
  wire [7:0] in_port;             // 
  wire [7:0] port_id;
  reg [7:0] in_port_reg;          // hold data for mcu
  assign in_port = in_port_reg;

// MIDI & TTY receivers
  wire [7:0] rx0data;
  wire rx0ready_status;
  wire reset_rx0ready_status;
  wire resetsignal;
// mcu
  wire read_strobe;
  wire write_strobe;
//////////////////////////////////////////////////////////////////////////////////////
// Synth signals

  reg [S-1:0] MCU_GATE = 0;

// Output values from processing of MIDI data.
  reg [6:0] MOD_WHL = 7'd64;                      // a usable initial value
  
  reg SUSTAIN = 1'b0;
  
  reg [6:0] VEL[S-1:0];               // dist RAM
  reg [6:0] NOTE[S-1:0];              // dist RAM

  reg [6:0] TRANSPOSE = 7'd36;              // global transposition in half steps.  The MIDI controller reads
                                            // this value and subtracts it from all note on message note numbers.
                                            // The synth hardware sees this adjusted value.

  reg [2:0] STR;                            // string select

// register to remember which strings are vibrating.  This is because the MIDI controller
// is programmed to show the true state of each key, only held keys have GATE high.
// But because of the sustain pedal, a string can be vibrating even if GATE is low.
// This register contains one bit per string.  The bit is set when the string is plucked
// and reset when the string is squelched.  Squelch occurs either on when both GATE and
// ACTIVE are low for a given string.
// This register is made available to the MCU for controlling voice assignment.
  reg [7:0] ACTIVE = 8'b00000000;

  reg [6:0] N;              // state machine NOTE working register
  reg [6:0] V;              // state machine VEL working register

//////////////////////////////////////////////////////////////////////////////////////
// POR delay FF chain
  FDCE rst_bit0 (.Q(rstd[0]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(1'b1));
  FDCE rst_bit1 (.Q(rstd[1]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[0]));
  FDCE rst_bit2 (.Q(rstd[2]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[1]));
  FDCE rst_bit3 (.Q(rstd[3]), .C(clk), .CE(1'b1), .CLR(1'b0), .D(rstd[2]));
  assign reset = ~rstd[3] | PUSH_RESET;

//////////////////////////////////////////////////////////////////////////////////////
// instantiate the uC (kcpsm3) with it's ROM

  kcpsm3 MCU0 ( .address(address), .instruction(instruction), .port_id(port_id), 
    .write_strobe(write_strobe), .out_port(out_port), .read_strobe(read_strobe), .in_port(in_port), 
    .interrupt(interrupt), .interrupt_ack(interrupt_ack), 
    .reset(reset), .clk(clk) );  

  midictrl PSM0 ( .address(address), .instruction(instruction), .clk(clk) );
  
  // MIDI receiver.  31,250 Baud
  assign resetsignal = write_strobe && ( port_id == 8'hFF );  // When port_id == FF with write strobe, reset the UARTs
  assign MIDI_In = Raw_MIDI_In;                    // Don't invert the MIDI serial stream for 6N138
  // assign MIDI_In = ~Raw_MIDI_In;                // Invert the MIDI serial stream

//////////////////////////////////////////////////////////////////////////////////////
// MIDI UART
// UART code by Jim Patchell
  MIDIuartrx RX0 ( .dout(rx0data), .clk(clk), .reset(resetsignal), .rxd(MIDI_In), 
    .frame(), .overrun(), .ready(), .busy(), .CS(), 
    .interrupt(interrupt0), .interrupt_ack(interrupt_ack), 
    .rxready_status(rx0ready_status), 
    .reset_rxready_status(reset_rx0ready_status) );
  /////// VERY IMPORTANT HARDWARE /////////////////////////////////////////////
  // decode read port 01, send pulse to reset rxready flop
  // This allows the mcu to clear the rxready bit automatically just by reading rxdata.
  assign reset_rx0ready_status = (read_strobe == 1'b1) & (port_id[4:0] == 5'h01);
  assign interrupt = interrupt0;

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
// DAC - This DAC version accepts value 'cycles' which determines the amount of time between enables.

  reg signed  [23:0] DACreg = 24'h0;
  wire signed [23:0] DACbus;

  i2s_out DAC ( .clk( clk ), .reset( reset ), .l_data( DACreg ), .r_data( DACreg ), .sdout( DIGI1[3] ), 
              .sclk( DIGI1[2] ), .lrclk( DIGI1[1] ), .load( DACena) );

  assign DIGI1[0] = clk;   // clk serves as master clock

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
// This ROM provides tuning, delivers length value for MIDI note number.

  reg  [10:0] WGlen;                   // holds string's length for state machine
  wire [10:0] WGlenROM;

  tun TUN ( .O( WGlenROM ), .A( N[5:0] ) );        // tuning ROM to translate MIDI note numbers to waveguide length
  
//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//
//==//==//==//==//==//==//==//==//==//==//  WAVEGUIDE RAM   //==//==//==//==//==//==//==//==//==//==//==//
//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//==//
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// String RAM (for delay lines)

  reg [17:0]  wgRAM [16383:0];              // BLOCK RAM   waveguide RAM.  Holds 8 waveguides.  Upper 3 address bits select the waveguide
                                            // Note that this will allocate 18 block RAMs.

  reg  [10:0] SDLadr[S-1:0];                // dist RAM    address register for each string.  Upper 3 address bits select the waveguide
  reg  [17:0] SDLin = 18'h0000;             // register holds data for next RAM write
  reg  [17:0] SDLout;                       // RAM output
  wire [13:0] addr;
  reg  [10:0] WGadr;                        // state machine waveguide address register
  reg         RAMWRT = 1'b0;
  
  assign addr = {STR,WGadr};

  always @ ( posedge clk )
    begin
    if ( RAMWRT ) wgRAM[addr] <= SDLin;    // write RAM on any FFCLR signal
    SDLout <= wgRAM[addr];
    end

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
// Reflection point filter -  a single filter is shared between all 8 strings.
  reg                IIRena = 1'b0;
  reg  signed [17:0] IIRin;          // IIR0in is input register for IIR0, also serves as string loop output
  wire signed [17:0] IIRout;         // output of filter
  reg  signed [17:0] IIRoutREG;
  wire        [35:0] Delay;          // filter's delay value
  reg         [35:0] BW;             // bandwidth

  // Sign extend IIRin as IIRinX
  wire signed [21:0] IIRinX;
  
  assign IIRinX = {IIRin[17],IIRin[17],IIRin[17],IIRin[17],IIRin};

  assign Delay = 36'h7FFFFFFFF - BW ;

  IIRnew IIR ( .clk(clk), .ena(IIRena), .I(IIRin), .DEL(Delay), .SEL(STR), .O(IIRout) );
	 
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
// Comb Filter Delay Line RAMs
// input to the filter is .I, the RAM input.

  wire        [17:0]  CFDLout;            // comb filter delay line RAM output

  reg         [7:0]   CFDLadr[S-1:0];     // dist RAM  CFDL address register 8 bits (256x18 RAM) per string
  reg         [7:0]   CFadr = 8'h00;      // register holds CFDLadr for state machine
  reg         [7:0]   CFlen = 8'h00;      // state machine CF length register

  DL2048 CFDL ( .A({STR,CFadr}), .I(IIRin), .O(CFDLout), .WRT(RAMWRT), .clk(clk) );
  
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
// Gate change detection objects:
  reg [S-1:0] old_GATE = 0;
  wire [S-1:0] GATEchgd;

//////////////////////////////////////////////////////////////////////////////////////
// for EXval:
  reg signed [17:0] EXval[S-1:0];   // dist RAM  waveguide EXval (excitation value) signal;
  reg signed [17:0] EXvaltmp;       // temp reg for computing EXval[] per string
  reg [S-1:0] EX = 1'b0;            // flag - hi = excite active
  reg [12:0] EXcnt[S-1:0];          // dist RAM  EXval pulse width counter
  reg [12:0] EXcnttmp;              // temp reg for computing EXcnt[] per string
  
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
// Waveguide state machine

  reg [3:0] state = 4'h0;
  reg run = 1'b0;

  reg [S-1:0] sign;              // used to invert sign for each excite to prevent "charging" the system.

  reg [21:0] CFsum = 22'h000000;
//  assign DACbus = ( CFsum >>> 10 ) + 12'b100000000000 ;      // Output from comb filter sum
  assign DACbus = {CFsum,2'b00};   // this DAC accepts 24 bit signed data

//////////////////////////////////////////////////////////////////////////////////////

  wire [S-1:0] pluck;                          // what the pluck?  This is a string synth...

  reg  [S-1:0] FFCLR = 0;                      // pluck flipflop clears

//////////////////////////////////////////////////////////////////////////////////////

  assign GATEchgd = MCU_GATE ^ old_GATE;       // true whenever gate signal changes state.

//////////////////////////////////////////////////////////////////////////////////////
//  wire signed [17:0] WGin;                       // Waveguide inputs
//  assign WGin = ( sign[STR] == 1'b1 ) ? (-IIRoutREG + EXvaltmp) : (-IIRoutREG - EXvaltmp) ;
  reg signed [17:0] WGin = 0;
  reg signed [17:0] WGinP = 0;
  reg signed [17:0] WGinN = 0;

//////////////////////////////////////////////////////////////////////////////////////
// squelch slow down:
  parameter sq_cnt_MAX = 5;  // number of samples between halving output
  reg [5:0] sq_cnt = 0;

//////////////////////////////////////////////////////////////////////////////////////
// overflow detection:
  wire oflo;
  assign oflo = (( EXvaltmp[17] ^ IIRoutREG[17] ) & ( WGin[17] ^ EXvaltmp[17] ));

//////////////////////////////////////////////////////////////////////////////////////
// this should create a crude control for the value in ROTval which drives the filter's BW value
  reg [12:0] ROTval = 13'b0001000000000;  // name "ROTval" is original design, had rotary encoder
  reg [7:0] ctr = 0;    // to slow things down
  always @ ( posedge clk )
    begin
    if ( DACena == 1'b1 )
      begin
      ctr <= ctr + 1;
      if ( ctr == 0 )
        begin
        if ( PUSH_A == 1'b1 ) ROTval <= ROTval + 1;
        else
          begin
          if ( PUSH_B == 1'b1 ) ROTval <= ROTval - 1;
          end
        end  
      end
    end    

//////////////////////////////////////////////////////////////////////////////////////
//  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //
//////////////////////////////////////////////////////////////////////////////////////  
// state machine structure:

  always @ ( posedge clk )
    begin
    if ( DACena )
      begin
      state <= 4'h0;                            // starting state
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
        
        4'h0:                        // initialize for this string
          begin  state <= state + 4'h1;
          N <= NOTE[STR];            // get note value to N register from NOTE RAM
          V <= VEL[STR];             // get vel value to V register from VEL RAM
          WGadr <= SDLadr[STR];      // set waveguide address
          CFadr <= CFDLadr[STR];     // set comb filter address
          end

        4'h1:                        
          begin  state <= state + 4'h1;
          // This is a nice effect.
          BW <= {1'b0,ROTval,22'h000000} + ((N + V) << 27);
          end

        4'h2:
          begin  state <= state + 4'h1;
          WGlen <= WGlenROM ;         // tunADR is now stable, get waveguide length for this string
          IIRin <= SDLout;            // transfer current string waveguide output to IIR input register
          IIRena <= 1'b1;             // tell filter to go, takes 3 clocks          
          end

        4'h3:                         // filter cycle 1 complete
          begin  state <= state + 4'h1;

          IIRena <= 1'b0;             // deassert the filter go flag
          
          EXvaltmp <= EXval[STR];    // sets default value for EXvaltmp in case next state's logic doesn't change it.
          EXcnttmp <= EXcnt[STR];
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

        4'h4:                         // filter cycle 2 complete
          begin  state <= state + 4'h1;

          // This code generates either saw or pulse depending on SW[2].  0 - pulse, 1 - saw
          if ( pluck[STR] == 1'b1 )
            begin          
            ACTIVE[STR] <= 1'b1;                            // turn on ACTIVE flag for this string
            EX[STR] <= 1'b1;                                // turn on flag excite to start pulse
            sign[STR] <= ~sign[STR];                        // alternates which way the excite signal is signed.
            
            // rect pulse
            EXcnttmp <= {2'b00,WGlen[10:0]} ;
            EXvaltmp <= {2'b01,V,9'b000000000} ;
            end
            
          else        // else if NOT pluck:

            begin
            if ( EX[STR] == 1'b1 )        // if this string is currently being excited:
              begin
              EXcnttmp <= EXcnttmp - 13'h0001;        // for rectangular pulse

              if ( EXcnttmp == 13'h0000 )
                begin
                EXvaltmp <= 18'h00000;                  // return value to zero
                EX[STR] <= 1'b0;                        // turn off flag excite to end pulse
                end
              end
            end
          end

        4'h5:                         // filter cycle 3 complete.  IIRout is valid
          begin  state <= state + 4'h1;
          IIRoutREG <= IIRout;
          end

        4'h6:
          begin  state <= state + 4'h1;
          WGinP <= -IIRoutREG + EXvaltmp;
          WGinN <= -IIRoutREG - EXvaltmp; 
          end

        4'h7:
          begin  state <= state + 4'h1;
          WGin <= ( sign[STR] ) ? WGinP : WGinN ;
          end

        4'h8:
          begin  state <= state + 4'h1;
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

        4'h9:
          begin  state <= 4'h0;               // set state to start of string process

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
///////////////////////////////////////////////////////////////////////////////  
// Decode structures for hardware receiving data from the MCU

  always @ ( posedge clk )
    begin
    if ( write_strobe == 1'b1 )
      begin
// This case block contains selection logic for system level ports and for CC ports.
// Note that these ports all have  bit 7 of port_id set.
      casex ( port_id[4:0] )
        5'b00xxx: VEL[port_id[2:0]]     <= out_port[6:0];    // addresses all 8 velocity ports
        5'b01xxx: NOTE[port_id[2:0]]    <= out_port[6:0];    // addresses all 8 note number ports
        5'h11: MOD_WHL                  <= out_port[6:0];    // modulation wheel, global
        5'h12: SUSTAIN                  <= out_port[6];      // SUSTAIN pedal
        5'h13: MCU_GATE                 <= out_port[S-1:0];  // MCU_GATE signal, per voice.
      endcase
      end
    end

// make sure that in_port_reg always contains selected data at rising edge of clk,
// PicoBlaze will read it when it needs it.
  always @ ( posedge clk ) 
    begin
    case ( port_id[2:0] )                              // decode and transfer data to in_port_reg
      3'h0: in_port_reg    <= {1'b0,rx0ready_status,6'b000000}; // UART1 & UART0 rxready bits
      3'h1: in_port_reg    <= rx0data;                 // MIDI UART rxdata
      3'h2: in_port_reg    <= {8'h0};                  // MIDI CHANNEL - change this number to change the channel
      3'h3: in_port_reg    <= {1'b0,TRANSPOSE};
      3'h6: in_port_reg    <= ACTIVE;                  // vibrational state of each string
      default: in_port_reg <= 8'bxxxxxxxx;
    endcase
    end

/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
// LEDs

  assign led = ROTval[12:9];
//  assign led = MOD_WHL[6:3];
// assign led = {~{MIDI_In,MIDI_In,MIDI_In,MIDI_In}} ;
//assign led = { MCU_GATE[0] | MCU_GATE[4], MCU_GATE[1] | MCU_GATE[5], MCU_GATE[2] | MCU_GATE[6], MCU_GATE[3] | MCU_GATE[7] } ;
endmodule
