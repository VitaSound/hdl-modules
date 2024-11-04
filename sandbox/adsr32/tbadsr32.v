module tbadsr32;
  
  reg clk;         // 50 MHz
  wire [31:0] sout; // This is the accumulator/integrator for attack, decay and release
  reg GATE;        // GATE signal
  reg [31:0] A;    // attack rate
  reg [31:0] D;    // decay rate
  reg [31:0] S;    // sustain level
  reg [31:0] R;    // release rate

  wire [2:0] state;                 // state 0,1,2,3,4,5 - IDLE,ATTACK,DECAY,SUSTAIN,RELEASE
  
 
initial begin
  GATE = 0;
  A = 0;
  D = 3'b010;
  S = 3'b011;
  R = 3'b100;
  //assign state = 0;
end


adsr32 ADSRnew(
  .clk(clk), 
  .GATE(GATE), 
  .A(A), 
  .D(D), 
  .S(S), 
  .R(R), 
  .sout(sout));

initial
begin
    
    
    $dumpfile("out.vcd");
    $dumpvars(0,tbadsr32);   
    $display("starting testbench!!!!");
    
    $display("clk GATE     A          D          S          R         sout state");

    $monitor(clk,, GATE,, A,, D,, S,, R,, sout,,    state);
  
        clk <= 0; 
        repeat (5)  //500000
            
        begin
                #10;
                clk <= 1;
                #10;
                clk <= 0; 
        end
           

    $display("finished OK!");
    
end

endmodule