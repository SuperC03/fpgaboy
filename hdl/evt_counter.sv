`default_nettype none

module evt_counter
  #(parameter MAX_COUNT = 115_200)
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[$clog2(MAX_COUNT)-1:0]  count_out
  );
  logic[$clog2(MAX_COUNT)-1:0] count;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count <= $clog2(MAX_COUNT)'('b0);
    end else if (evt_in) begin
      // Implements modulo logic to evt_counter.
      if (count == $clog2(MAX_COUNT)'(MAX_COUNT - 1)) begin
        count <= $clog2(MAX_COUNT)'('b0);
      end else begin
        count <= count + $clog2(MAX_COUNT)'('b1);
      end
    end
  end

  always_comb begin
    if (rst_in) begin
      count_out = $clog2(MAX_COUNT)'('b0);
    end else begin
      if (evt_in) begin
        count_out = count == $clog2(MAX_COUNT)'(MAX_COUNT - 1) ?
                      $clog2(MAX_COUNT)'('b0) : count + $clog2(MAX_COUNT)'('b1);
      end else begin
        count_out = count;
      end
    end
  end
endmodule

`default_nettype wire
