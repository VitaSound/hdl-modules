# fpga.synth.net

пропал с радаров интернета. но wayback машина все помнит. (к сожалению, не все)

https://web.archive.org/web/20171003065045/http://www.fpga.synth.net/pmwiki/




# dsdac

https://web.archive.org/web/20170926155227/http://www.fpga.synth.net/modules/dsdac.shtml

Delta Sigma Modulator
A simple, first order Delta Sigma Modulator
Submitted by Jim Patchell

Delta Sigma Modulator for doing Digital->Analog Conversion
This is a first order delta sigma converter...it will be fairly low quality because of that.
One note...this was something I did at work...I just typed it in again here at home...it does compile...but I don't know if it works...I will try and test it real soon.

Use:
clk............system clock
reset.........system reset
d..............data input, 16 bits (this is the audio data)
wd............Write data into holding register
sample......Bit stream sample rate input
bs.............Bit Stream output (goes to LP filter)
ready........Holding register is ready for next data word

Source:
The source is here deltasigma.v
It is free, but please leave the authors name and webpage link in the code


# SVF

Digital State Variable Filter

Description: This article involves the research and implementation of an FPGA based digital state variable filter.

I found this resource and from the information there, I wrote a C program which implements the SVF using floating point arithmetic. The filter appears to be doing what it is supposed to, spectral charts indicate that Q values above 1.0 create a pronounced resonance peak.

According to the resource above, the digital state variable filter should not be expected to remain stable with input signals at frequencies more than 1/6 the sample rate especially with higher values of Q. My intention is to use this filter in a second version of the GateMan which will have a sample rate of 1 MHz, quite plenty for a digital SVF in a musical application. I am hopeful that a GateMan with an SVF will sound more like a PAiA FatMan.

An attractive thing about the SVF is that it is very easy to tune - it requires only one value to control frequency and one value to control Q. Also, as can be seen (below the C code), the function that is used to calculate the value of f is fairly linear at the low end where these tests will execute. This makes using f easy to describe frequency without actually doing the calculation.

Note that q in the block diagram represents an input equal to 1/Q.

State Variable Filter Block Diagram:

SVF_Block_Diagram.gif

Some C code for state variable lowpass filter follows:

```
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

#define BUFSIZE 1024

int main( int argc, char *argv[] )
{
char buf[BUFSIZE];
double input;
double sum1,sum2,sum3;
double fb1,fb2;
double f;
double q, Q;
double mult1,mult2,multq;
double output = 0.0;

f = 0.01;
Q = 2.0;    // 0.5 to infinity

if ( argc > 1 ) f = atof( argv[1] );
if ( argc > 2 ) Q = atof( argv[2] );

q = 1.0 / Q;

while ( fgets( buf, BUFSIZE, stdin ) != NULL )
  {
  input = atof( buf );

  multq = fb1 * q;

  sum1 = input + (-multq) + (-output); 

  mult1 = f * sum1;
  sum2 = mult1 + fb1;      

  mult2 = f * fb1;
  sum3 = mult2 + fb2;

  fb1 = sum2;
  fb2 = sum3;

  output = sum3;
  printf( "%20.18lf\n", output );
  }
}
```

Note that to express frequency in Hertz, the value f really needs to be computed using:

```
              pi * Fc        
f = 2 * sin( ---------- )
                 Fs
```

where Fs is the sample rate and Fc is the corner frequency of the filter (in Hz).

Since I really didn't care about expressing frequency in Hz, I simply supplied raw f values.

Verilog

I've built a simple test project which supplies a square wave signal to the SVF. The sample rate is 1.0 MHz. This filter uses signed 18 bit arithmetic and it achieved a maximum Q of about 23.46 with a signed 12 bit input.

Here is the Verilog source:

ScottG_SVF.zip (LOST)

This S-3Esk project presents an audio frequency square wave (12 bits) to the filter. You can control the f value with the rotary encoder. Two frequencies are available by pressing or not pressing the east button. The filter module is SVF.v. I've both listened to and watched the output from the DAC on an oscope. The filter performs satisfactorily. With high Q, the filter is quite selective and performs much like an analog SVF, you can sweep the f value and you will hear it pick out individual harmonics. Currently, the filter has only a lowpass output, but the others are easy to add.

Here is a sound sample of a filter sweep with a sawtooth input. Q was maxed at 23.46.

ScottG_SVFsweep.wav (LOST)

# gateman i

https://web.archive.org/web/20170903132254/http://www.fpga.synth.net/pmwiki/pmwiki.php?n=FPGASynth.GateManI

GateMan_It.zip

# gateman ii

https://web.archive.org/web/20170903132259/http://www.fpga.synth.net/pmwiki/pmwiki.php?n=FPGASynth.GateManII

source is lost!

# digital wave guide

https://web.archive.org/web/20170903132431/http://www.fpga.synth.net/pmwiki/pmwiki.php?n=FPGASynth.DigitalWaveguide

K_S_Block_Diagram.gif

DWG_monosynth_ver_g.zip

PolyDaWG8.zip

PolyDaWG8_ver_oa.zip

# gateman poly

https://web.archive.org/web/20170903132636/http://www.fpga.synth.net/pmwiki/pmwiki.php?n=FPGASynth.GateManPoly

GateManPoly_Block_Diag.gif

lost (((

# 8 Voice 2 Operator FM MIDI Polysynth

https://web.archive.org/web/20170718172816/http://www.fpga.synth.net/pmwiki/pmwiki.php?n=FPGASynth.8vFM-2x4

8vFM-2x4.zip

FM_Sound_Gen_Block_Diag.gif

# FPGA Drone Synth

https://web.archive.org/web/20170903132436/http://www.fpga.synth.net/pmwiki/pmwiki.php?n=FPGASynth.DroneSynth

SineSynth_ver_d.zip