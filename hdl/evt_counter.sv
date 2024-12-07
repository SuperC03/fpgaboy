`default_nettype none

module EvtCounter
  #(parameter MAX_COUNT = 115_200)
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[$clog2(MAX_COUNT):0]  count_out
  );
  
  // Tracks the number of evt_in detected.
  logic [$clog2(MAX_COUNT):0] count;
  always_ff @(posedge clk_in) begin
    count <= count_out;
  end

  // Logic to determine the next count value.
  always_comb begin
    if (rst_in) begin
      count_out = $clog2(MAX_COUNT)'('h0);
    end else if (evt_in) begin
      if (count_out == (MAX_COUNT - 1)) begin
        count_out = $clog2(MAX_COUNT)'('h0);
      end else begin
        count_out = count + $clog2(MAX_COUNT)'('h1);
      end
    end else begin
      count_out = count;
    end
  end
endmodule

`default_nettype wire
