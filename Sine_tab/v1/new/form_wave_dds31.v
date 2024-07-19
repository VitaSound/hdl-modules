module form_wave_dds31 (

    input wire CLK,
    input wire RESET,

    input wire [31:0] DDS,               
    output reg [31:0] DDSout_dds31, 

    input wire [2:0] form,
    input wire [6:0] pulse_width

);

 always@(posedge CLK or posedge RESET)

   case(form)    
     3'b000: begin          // saw+          
       DDSout_dds31 <= DDS;
     end

     3'b001:  begin        //reverse saw+          
       DDSout_dds31 <= -DDS;
     end

    3'b010:  begin       //triangle+         
      if (DDS [31] == 1'b0)
        DDSout_dds31 <= DDS;
      else
        DDSout_dds31 <= -DDS;
    end
 
    3'b011: begin      //meander+                  
      DDSout_dds31 <= DDS [31];
    end


    3'b100: begin      //meander025                    
      if(DDS [31:24] <= pulse_width) 
        DDSout_dds31 <=1'b1;
      else 
        DDSout_dds31 <=1'b0;
    end

   endcase   
endmodule
