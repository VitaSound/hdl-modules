 `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Scott Gravenhorst
// 
// Create Date:    15:17:09 06/25/2007 
// Design Name:    Digital Waveguide Synthesizer Experiment
// Module Name:    DWG 
// Project Name:     Digital Waveguide Synthesizer Experiment
// Target Devices:   xc3s500e
//
// Waveguide: two 2048 location by 18 bit wide RAMs
// Sample Rate: 250,000 samples per second.
//
//////////////////////////////////////////////////////////////////////////////////
//                                BTN_N : microcontroller reset
//                                                   
//   BTN_W  : delta filter multiplier (64x)                    BTN_E  : squelch 
//
//                                BTN_S :  
//                              when enabled,
//                              pressed: LEDs show lower 7 bits of bandwidth reg, 
//                              otherwise: LEDs show upper 8 bits of bandwidth reg.
//////////////////////////////////////////////////////////////////////////////////
//
// ver_a - This is a test version.  Only one delay line is used, but we will still
//         implement the pickup, just at only one position.
//
//         converted case structure in state machine to simple if begin/end blocks
//
// ver_b - Single delay line approach.  However 2 delay lines are actually used, just
//         not in the dual delay line sense.  In this version, I will use the single
//         delay line model connected to a delay line based comb filter.  Changing the 
//         delay for the comb filter changes the position of the pickup.
//         Code cleanup, tightened state machine, total of 5 states.
//
// ver_c - Object name changes to accomodate additional RAM for comb filter.
//         Add 128x18 delay line for pickup position comb filter
//
//////////////////////////////////////////////////////////////////////////////////
module DWG( clk, led,
            lcd_rs, lcd_rw, lcd_e, lcd_d, 
            ROTa, ROTb, ROTpress,
            BTN_E, BTN_W, BTN_N, BTN_S,
            spi_sck, spi_sdi, spi_dac_cs, spi_sdi, spi_sdo, spi_rom_cs, 
            spi_amp_cs, spi_adc_conv, spi_dac_cs, spi_amp_shdn, spi_dac_clr,
            strataflash_oe, strataflash_ce, strataflash_we,
            platformflash_oe,
            SW, 
            Raw_MIDI_In,
            TTY_In );

  input clk;
  output [7:0] led;
  
  inout [7:4] lcd_d;
  output lcd_rs;
  output lcd_rw;
  output lcd_e;
  
  input ROTa;
  input ROTb;
  input ROTpress;
  
  input BTN_E;
  input BTN_W;
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
  
  reg [7:0] LCD;      // written to by MCU
  
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
  wire BTN_E, BTN_W, BTN_N, BTN_S;

//  wire ROTpress_out;

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

  reg       MCU_GATE = 1'b0;
  reg [6:0] SYSEX_ADDR_MSB = 7'h00;

// Output values from processing of MIDI data.
  reg [6:0] MOD_WHL;
  reg [6:0] VEL;

  reg [7:0] NOTE0;

  reg [6:0] TRANSPOSE = 7'h00;              // global transposition in half steps

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

// common
  assign interrupt = (interrupt0 | interrupt1);  // ISR gets to figure out which UART did it.

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// DAC
// The following is logic to divide the ena_out signal from the spi_dac_out
// module by N and preserve the original pulse width.
//
// Hook to DACena for 250000 samples per second.
//

  reg [11:0] DACreg = 12'b100000000000;  // used by SPI DAC
  wire [11:0] DACbus;
  wire ena_out;

  reg [2:0] DACcnt = 3'b000;
  reg DACena = 1'b0;
  
  always @ ( posedge clk )
    begin
    if ( ena_out == 1'b1 )
      begin
		  DACcnt <= DACcnt + 3'b001;
      if ( DACcnt == 3'b011 )              // 1 for 500 KHz, 3 for 250 KHz, 7 for 125 KHz
		    begin
		    DACena <= 1'b1;
		    DACcnt <= 3'b000;
		    end
      end   
    else DACena <= 1'b0 ;
    end

// DAC, module by Eric Brombaugh
  spi_dac_out DAC (.clk(clk),.reset(reset),
                   .spi_sck(spi_sck),.spi_sdo(spi_sdi),.spi_dac_cs(spi_dac_cs),
                   .ena_out( ena_out ),.data_in( DACreg ));

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// This ROM provides tuning, delivers length value for MIDI note number.

  wire signed [13:0] WGlen;  // 11 bits with a sign bit that should always be zero
  reg [5:0] tunADR;              

  always @ ( posedge clk ) 
    begin
    if ( DACena ) tunADR <= NOTE0[5:0] - 16 ;
    end
   	
  tun TUN ( .O(WGlen[10:0]), .A(tunADR) );  // tuning ROM to translate MIDI note numbers to waveguide length
  
  assign WGlen[13:11] = 3'b000;             // fix sign bit to zero, headroom bits to zero

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// String RAMs (delay lines), right and left

  reg signed [13:0] SDLptr = 14'sh0000;     // RAM delay line read/write pointer
  
  reg signed [13:0] SDLadr = 14'h0000;      // RAM address register * sign bit is for detecting under/overflow
  reg SDLWRT = 1'b0;                        // RAM write enable
  reg [17:0] SDLin;                     // register holds data for next RAM write
  wire signed [17:0] SDLout;            // RAM output, right

  DL DL0 (.clk(clk),.WRT(SDLWRT),.A(SDLadr[10:0]),.I(SDLin),.O(SDLout));  // delay line RAM right

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Reflection point filters

  reg signed [17:0] IIR0in;           // IIR0in is input register for IIR0, also serves as string loop output
  wire signed [17:0] IIR0out;
  wire [35:0] Delay;
  reg signed [17:0] IIR0FB;           // IIR0 feedback storage
  
  reg [35:0] BW;                              // bandwidth
  always @ ( posedge clk )
    begin                        // keyboard tracking       
    if ( SW[3] == 1'b1 ) BW <= {1'b0,ROTval,20'h00000} + ((NOTE0-16) << 28);  // good for strings
    else                 BW <= {1'b0,ROTval,20'h00000} + ((NOTE0-8) << 25);   // good for tonal drums, set encoder very low
    end
  
  assign Delay = 36'h7FFFFFFFF - BW ;

// NOTE about this IIR filter: could use the multiplier's input registers, 
// probably don't need output registers.
//             18 bit     36 bit      18 bit      18 bit
  IIR IIR0 (.I(IIR0in),.DEL(Delay),.FB(IIR0FB),.O(IIR0out));

  always @ ( posedge clk ) if ( DACena ) IIR0FB <= IIR0out;     // filter 0 feedback
	 
/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
// Comb Filter Delay Line RAM
// input to the filter is .I, the RAM input.

  wire [17:0] CFDLout;             // comb filter delay line RAM output
  reg  signed [18:0] CFout;        // comb filter output
  reg  [9:0]  CFDLadr = 10'h000;   // CFDL address register 7 bits (128x18 RAM)
  reg         CFDLWRT = 1'b0;      // Write enable for comb filter delay line RAM

  CFDLBRAM CFDL (.clk(clk), .O(CFDLout), .I(IIR0in), .A(CFDLadr), .WRT(CFDLWRT));
  
  wire [9:0] CFDLlen;

//  assign CFDLlen = {2'b00,MOD_WHL,1'b0} + 10'h010;
  assign CFDLlen = (MOD_WHL << 1) + (MOD_WHL >> 1) + 10'h006 ;

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Gate changed objects:
  reg       old_GATE = 1'b0;
  wire      GATEchgd;    
///////////////////////////////////////////////////////////////////////////////
// for EXval:
  reg signed [17:0] EXval = 18'h00000;   // waveguide EXval signal;
  reg EX = 1'b0;                         // flag - hi = EXval pulse is high
  reg [12:0] EX_cnt = 13'h0000;          // EXval pulse width counter

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Waveguide state machine

  wire signed [17:0] logainP;  // low gain R positive
  wire signed [17:0] logainN;  // low gain R negative

  reg [5:0] state = 6'b000000;
  reg run = 1'b0;

  reg sign = 1'b0;              // saves the sign of IIR1 at excite time, used to invert when necessary,
                                // the sign of the EXval signal to prevent "charging" the system.

//  assign DACbus = ( IIR0in >>> 6 ) + 12'b100000000000 ;      // Output from string loop is IIR0in (a register)
  assign DACbus = ( CFout >>> 7 ) + 12'b100000000000 ;      // Output from comb filter
  
// / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / 

  wire press;
  
  assign GATEchgd = MCU_GATE ^ old_GATE;       // true whenever gate signal changes state.

  wire signed [17:0] WGin;
  wire oflo;                                   // overflow indicator
  
//  assign oflo = (( EXval[17] == ~IIR1out[17] ) && ( WGin[17] != EXval[17] )) ;
//  assign oflo = (( EXval[17] ^ IIR1out[17] ) & ( WGin[17] ^ EXval[17] )) ;
  assign oflo = (( EXval[17] ^ IIR0out[17] ) & ( WGin[17] ^ EXval[17] )) ;

//  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //
// low gain portion of nonlinearity:
  wire signed [20:0] mul3R;                             // conveys 3 * SDLout
  assign mul3R = (SDLout << 1) + SDLout;

  // calculate 3/4 * RAM value and add a constant for continuity of the function's output
  assign logainP = ( mul3R >>> 2 ) + 18'sh05FFF ;
  assign logainN = ( mul3R >>> 2 ) - 18'sh05FFF ;

//  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //
// compute the waveguide input sum, we apply clipping in state machine.
  assign WGin = ( sign == 1'b1 ) ? (-IIR0out + EXval) : (-IIR0out - EXval) ;

//  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  //  
// state machine structure:

  always @ ( posedge clk )
    begin
    if ( DACena )
      begin
      state <= 6'h00;                 // starting state
      run <= 1'b1;                    // tell state machine to run
      DACreg <= DACbus;               // write current DACbus value to DACreg for output
      SDLWRT <= 1'b0;                    // make sure SDLWRT starts out at zero
      SDLadr <= {3'b000,SDLptr[10:0]};    // set RAM address to read filter input data

      old_GATE <= MCU_GATE;
      
		  if ( SW[2] == 1'b0 )        // 0=rect pulse, 1=saw pulse
		    begin
        if ( EX == 1'b1 ) EX_cnt <= EX_cnt - 13'h0001;        // for rectangular pulse
        if ( (EX == 1'b1 && EX_cnt == 13'h0000) || MCU_GATE == 1'b0 )   // for rectangular pulse
		      begin
          EXval <= 18'h00000;            // return value to zero
          EX <= 1'b0;                    // turn off flag excite to end pulse
          end
        end
		  else
		    begin   // for saw                        17C00   1FC00
        if ( EX == 1'b1 && EXval >= 18'sh1FC00 || MCU_GATE == 1'b0 )
		      begin
          EXval <= 18'h00000;            // return value to zero
          EX <= 1'b0;                    // turn off flag excite to end pulse
          end
        end
      end
    else
      begin
		
		  if ( MCU_GATE == 1'b0 ) old_GATE <= 1'b0;
		
      if ( run )
        begin
        case ( state ) 

        6'h00:
          begin  state <= 6'h01;
          if ( SW[2] == 1'b0 )
			      begin
// for rectangular pulse
            if ( press == 1'b1 ) 
              begin
              sign <= ~sign;                   // determines which way the excite signal is signed.
		 	        EXval <= ( ( VEL << 10 ) + 18'b000000001111111111 );  // velocity controlled pulse
				      //EXval <= 18'sh1FFFF;  // velocity disabled
              EX <= 1'b1;                                   // turn on flag excite to start pulse
              EX_cnt <= {2'b00,WGlen[10:0]};         // make EX_cnt the size of the waveguide.
              end
            end
          else
			      begin
// single sawtooth, fixed width
            if ( press == 1'b1 ) 
            begin
            sign <= ~sign;                // determines which way the excite signal is signed.
			      EXval <= 18'h00000 ;
            EX <= 1'b1;                                   // turn on flag excite to start pulse
            end
		      else
		        begin
            if ( EX == 1'b1 ) EXval <= EXval + 18'sh00200 ;
			      end
				  end
        end


        6'h01: 
          begin  state <= 6'h02;
          if ( SDLout[17] == 1'b0 )   // if RAM data is zero or positive:
            begin
            if ( SDLout > 18'sh17FFF ) IIR0in <= logainP;
            else                       IIR0in <= SDLout;
            end
          else                          // if RAM data is negative:
            begin
            if ( SDLout < 18'sh28001 ) IIR0in <= logainN;
            else                       IIR0in <= SDLout;
            end

          if ( oflo == 0 )  // if oflo is zero, do normal stuff:
            begin
            if ( BTN_E == 1'b1 )        // squelch
              begin
              if ( ( WGin >>> 1 ) == 18'h3FFFF ) SDLin <= 18'h00000;
              else SDLin <= (WGin >>> 1);
              end
            else
              begin
              SDLin <= WGin;           // cue for next RAM write, non clipped (see below for oflo == 1)
              end
            end
          else        // an overflow has occured.  Do clipping here.
            begin
            if ( BTN_E == 1'b1 )        // squelch
              begin
              if ( (-IIR0out >>> 1) == 18'h3FFFF ) SDLin <= 18'h00000;
              else SDLin <= (-IIR0out) >>> 1;
              end
            else
              begin                    // CLIPPING:
              if ( sign == 1'b1 ) SDLin <= 18'h1FFFF ; // use positive maximum
              else                SDLin <= 18'h20001 ; // use negative maximum          
              end
            end
        
          end

        6'h02:
          begin  state <= 6'h03;
          SDLWRT <= 1'b1;                               // set RAM write enable
      // This creates the simple comb filter:
          CFout <= {IIR0in[17],IIR0in} - {CFDLout[17],CFDLout} ;
          end

        6'h03:
		      begin  state <= 6'h04;
          // increment SDLptr, wrap at 'WGlen'
          if ( (SDLptr + 1) < WGlen ) SDLptr <= (SDLptr + 1);
          else                        SDLptr <= 14'h0000;
          SDLWRT <= 1'b0;                               // reset RAM write enable
          CFDLWRT <= 1'b1;
          end

        6'h04:
          begin  state <= 6'h05;
          CFDLWRT <= 1'b0;
          
          if ( (CFDLadr + 1) < CFDLlen ) CFDLadr <= (CFDLadr + 1);
          else                           CFDLadr <= 9'h000;

          run <= 1'b0;                               // stop the state machine
          end
          
       endcase
      end
    end
  end  

  wire ffCLR;
  assign ffCLR = SDLWRT;
  wire SET_press;
  assign SET_press = GATEchgd & MCU_GATE;
  FDCPE #(.INIT(1'b0)) FDCPE_press (.Q(press),.C(1'b0),.CE(1'b0),.CLR(ffCLR),.D(1'b0),.PRE(SET_press));

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Rotary Encoder

ROTv3 ROT (.clk(clk),.ROTa(ROTa),.ROTb(ROTb),.ROTpress(ROTpress),.value_out(ROTval),
           .ROTpress_out( ROTpress_out ),.BTN_W( BTN_W ));

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////  
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////  
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////  
///////////////////////////////////////////////////////////////////////////////
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
     case ( port_id )
//      8'hF0: CHANpres    <= out_port[6:0];  // channel pressure value, global
//      8'hF1: PW[13:7]    <= out_port[6:0];  // pitch wheel MSB, global
//      8'hF2: PW[6:0]     <= out_port[6:0];  // pitch wheel LSB, global
      8'hF3: MOD_WHL     <= out_port[6:0];  // modulation wheel, global
//      8'hF4: JOYSTKx     <= out_port[6:0];  // JOYSTK X, global
//      8'hF5: JOYSTKy     <= out_port[6:0];  // JOYSTK Y, global
      8'hF8: MCU_GATE    <= out_port[0];    // MCU_GATE signal, per voice, right now just one voice.
      8'hF9: VEL         <= out_port[6:0];  // port to set synth hardware velocity register, per voice
      8'hFA: NOTE0       <= out_port[6:0];  // MIDI note number used for string 0 
   
//      8'hFE: MCULED <= out_port;
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
     8'h10: TRANSPOSE    <= out_port[6:0];   // global transpose by semitones, neg values don't work - fix this
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

// make sure that in_port_reg always contains selected data at rising edge of clk,
// PicoBlaze will read it when it needs it.
  always @ ( posedge clk ) 
  begin
    case ( port_id[3:0] )                        // decode and transfer data to in_port_reg
    4'h0: in_port_reg <= {rx1ready_status,rx0ready_status,6'b000000}; // UART1 & UART0 rxready bits
    4'h1: in_port_reg <= rx0data;                   // MIDI UART rxdata
    4'h2: in_port_reg <= {6'b000000,SW[1:0]};     // slide switches, 3 used to select MIDI chan 1-8.
    4'h7: in_port_reg <= {1'b0,TRANSPOSE};
    4'h8: in_port_reg <= rx1data;                   // TTY UART rxdata
    endcase
  end

/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
// LEDs

//assign led = diag_cnt[7:0];
  assign led = {4'b0000,press,MCU_GATE,GATEchgd,sign};


endmodule
