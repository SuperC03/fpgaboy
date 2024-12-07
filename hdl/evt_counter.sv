`default_nettype none

module EvtCounter
  #(parameter MAX_COUNT = 115_200)
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[$clog2(MAX_COUNT):0]  count_out
  );
 
  always_ff @(posedge clk_in) begin
    // Reset the counter.
    if (rst_in) begin
      count_out <= $clog2(MAX_COUNT)'('b0);
    // Increment the counter if an event is detected.
    end else if (evt_in) begin
      // Implements modulo logic to evt_counter.
      if (count_out == (MAX_COUNT - 1)) begin
        count_out <= $clog2(MAX_COUNT)'('b0);
      // Increment the counter regularly.
      end else begin
        count_out <= count_out + 1;
      end
    end
  end
endmodule

`default_nettype wire
