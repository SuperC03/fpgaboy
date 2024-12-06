`default_nettype none

module evt_counter
  #(parameter MAX_COUNT = 115_200)
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[$clog2(MAX_COUNT)-1:0]  count_out
  );
  // Tracks what the count is so far.
  logic [$clog2(MAX_COUNT)-1:0] count;

  // Updates the count based on the event.
  always_comb begin
    if (rst_in) begin
      count_out = $clog2(MAX_COUNT)'('b0);
    end else if (evt_in) begin
      count_out = count == $clog2(MAX_COUNT)'(
        $clog2(MAX_COUNT)'(MAX_COUNT - 'b1) ? 0 : count + 'b1
      );
    end else begin
      count_out = count;
    end
  end

  // Updates the count based on the event.
  always_ff @(posedge clk_in) begin
    count <= count_out;
  end
endmodule

`default_nettype wire
