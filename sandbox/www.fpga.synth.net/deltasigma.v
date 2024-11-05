module deltasigma(clk,reset,d,wd,sample,bs,ready);
//-----------------------------------------------------------
// Delta Sigma Modulator for doing Digital->Analog Conversion
// This is a first order delta sigma converter...it will be
// fairly low quality because of that.
//
// Created June 9, 2005
// by Jim Patchell
// This code is in the public domain
// You may use it as you see fit.
//
// One note...this was something I did at work...I just typed
// it in again here at home...it does compile...but I don't know
// if it works...I will try and test it real soon.
//-----------------------------------------------------------
// parameter:
//	clk........system clock
//	reset......system reset
//	d..........data input, 16 bits (this is the audio data)
//	wd.........Write data into holding register
//	sample.....Bit stream sample rate input
//	bs.........Bit Stream output (goes to LP filter)
//	ready......Holding register is ready for next data word
//-----------------------------------------------------------
    input clk;
    input reset;
    input [15:0] d;
    input wd;
    input sample;
    output bs;
    output ready;

	reg ready;		//indicates when holding register is ready for data
	reg bs;			//bit stream output
	reg [15:0]hold;	//data holding register
	reg [15:0]dr;		//working data register (loads from holding register)
	reg wdr;			//write to data register
	reg [17:0] acc;	//accumulator
	wire [17:0] t;		//temporary
	reg [3:0] bcntr;	//state counter
	reg [2:0] wcntr;	//word counter
	reg done;			//indicates that the current interation is done
	reg inc;			//increment word counter

	//---------------------------------------------------------
	// holding register logic
	//---------------------------------------------------------

	always @ (posedge clk or posedge reset)
	begin
		if(reset)
			hold <= 0;	//reset holding register to 0
		else begin
			if(wd)
				hold <= d;	//write incoming data to holding reg
			else
				hold <= hold;	//hold holding reg ... is this a pun :-)
		end
	end

	always @ (posedge clk or posedge reset)
	begin
		if (reset)
			ready <= 1;	//set ready bit...(hold register is empty)
		else begin
			if(wd)
				ready <= 0;	//hold register now has data in it
			else if (wdr)
				ready <= 1;	//data transfered to data reg...hold reg is empty
			else
				ready <= ready;	//hold current status
		end
	end

	//------------------------------------------------------------
	// Data register logic
	//------------------------------------------------------------

	always @ (posedge clk or posedge reset)
	begin
		if(reset)
			dr <= 0;	//clear data register
		else begin
			if(wdr)
				dr <= hold;	//load holding register into data register
			else
				dr <= dr;		//hold data register...
		end
	end

	always @ (done or ready)
	begin
		//---------------------------------------------------------------
		// when we are done processing a data word... it is
		// time to load the next word....we only do this
		// when a bit frame is "done" and the holding register
		// has some new data in it...ready = 0 indicates that
		// there is data waiting...ready = 1 means the holding
		// register is ready for new data
		//---------------------------------------------------------------
		if((done == 0) && (ready == 0))
			wdr = 0;
		else if ((done == 0) && (ready == 1))
			wdr = 0;
		else if ((done == 1) && (ready == 0))
			wdr = 1;		//update the data register from the hold register
		else if ((done == 1) && (ready == 1))
			wdr = 0;
		else
			wdr = 0;
	end

	//----------------------------------------------------------------------
	// Delta Sigma Converter
	//----------------------------------------------------------------------

	always @ (posedge clk or posedge reset)
	begin
		if(reset)
			bs <= 0;
		else begin
			if(sample)
				bs <= !acc[17];	//if acc >= 0, bs = 1
			else
				bs <= bs;
		end
	end

	assign t = bs ? 18'b000111111111111111:18'b111000000000000001;

	always @ (posedge clk or posedge reset)
	begin
		if(reset)
			acc <= 0;
		else begin
		//-------------------------------------------
		// this is the delta sigma calculation....
		//-------------------------------------------
			if(sample)
				acc <= acc + ({dr[15],dr[15],dr} - t);
			else
				acc <= acc;	//hold accumulator
		end
	end

	//------------------------------------------------------------------------
	// state counters
	//------------------------------------------------------------------------

	always @ (posedge clk)
	begin
		if(sample)
			bcntr <= bcntr + 1;	//bit stream counter increment
		else
			bcntr <= bcntr;	//hold count
	end

	always @ (posedge clk)
	begin
		if(inc)
			wcntr <= wcntr + 1;
		else
			wcntr <= wcntr;
	end

	// state decodes

	always @ (wcntr or bcntr or sample or ready)
	begin
		if(bcntr == 4'b1111) begin
			if((wcntr == 3'b111) && !ready) begin	//there is data in holding register
				if(sample)
					inc = 1;	//incement word counter
				else
					inc = 0;
			end
			else if ((wcntr != 3'b111) && sample)
				inc = 1;	//increment word counter
			else
				inc = 0;
		end
		else
			inc = 0;
	end

	always @ (bcntr or wcntr or sample)
	begin
		if((bcntr == 4'b1111) && (wcntr == 3'b111) && (sample == 1))
			done = 1;
		else
			done = 0;
	end

endmodule
