`timescale 1us / 1ns

module testbench();

//assume basic clock is 10Mhz
reg clk;
initial clk=0;
always
  #0.05 clk = ~clk;

//make reset signal at begin of simulation
reg reset;
initial
begin
  reset = 1;
  #0.1;
  reset = 0;
end

//function calculating sinus
function real sin;
input x;
real x;
real x1,y,y2,y3,y5,y7,sum,sign;
 begin
  sign = 1.0;
  x1 = x;
  if (x1<0)
  begin
   x1 = -x1;
   sign = -1.0;
  end
  while (x1 > 3.14159265/2.0)
  begin
   x1 = x1 - 3.14159265;
   sign = -1.0*sign;
  end  
  y = x1*2/3.14159265;
  y2 = y*y;
  y3 = y*y2;
  y5 = y3*y2;
  y7 = y5*y2;
  sum = 1.570794*y - 0.645962*y3 +
      0.079692*y5 - 0.004681712*y7;
  sin = sign*sum;
 end
endfunction

//generate requested "freq" digital
integer freq;
reg [31:0]cnt;
reg cnt_edge;
always @(posedge clk or posedge reset)
begin
  if(reset)
  begin
   cnt <=0;
   cnt_edge <= 1'b0;
  end
  else
  if( cnt>=(10000000/(freq*64)-1) )
  begin
   cnt<=0;
   cnt_edge <= 1'b1;
  end
  else
  begin
   cnt<=cnt+1;
   cnt_edge <= 1'b0;
  end
end

real my_time;
real sin_real;
reg signed [15:0]sin_val;

//generate requested "freq" sinus
always @(posedge cnt_edge)
begin
 sin_real <= sin(my_time);
 sin_val  <= sin_real*32000;
  my_time  <= my_time+3.14159265*2/64;
end

initial
begin
  $dumpfile("out.vcd");
  $dumpvars(0,testbench);
  my_time=0;

  
  freq=500;
  #10000;
 /* freq=1000;
   #10000;
  freq=1500;
   #10000;
*/



  $finish;
end
endmodule