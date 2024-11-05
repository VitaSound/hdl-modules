// email: music.maker@gte.net
// title: debounce.v
// author: Scott R. Gravenhorst
// date: 2006-08-12
// a module that waits 20 ms for the switch signal to settle before changing
// the switch state flipflop

module debounce( clk, I, O );
  input clk;
  input I;         // connect to input, noisey switch
  output O;        // output of debounced switch state
  
  reg O_state=1'b0;
  integer debounce_counter;
  
  assign O = O_state;
  
  always @ ( posedge clk )
    begin
    if ( I != O_state )
      begin
      if ( debounce_counter == 1000000 )
        begin
         O_state <= I;
        debounce_counter <= 0;
        end
      else
        begin
          debounce_counter <= debounce_counter + 1;
        end
      end
    else
      begin
      debounce_counter <= 0;
      end
    end  
endmodule
