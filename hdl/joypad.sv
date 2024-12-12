`timescale 1ns / 1ps
`default_nettype none

module Joypad (
  input wire clk_in,
  input wire rst_in,
  // Selectors for output matrix (https://gbdev.io/pandocs/Joypad_Input.html#ff00--p1joyp-joypad)
  input wire sel_btns,
  input wire sel_dpad,
  // Joypad input mappings
  // 0 -> A, 1 -> B, 2 -> Select, 3 -> Start
  // 4 -> Right, 5 -> Left, 6 -> Up, 7 -> Down
  input wire [7:0] pmoda,
  // Output depending on selectors (note that output is inverted)
  output logic [3:0] mtrx_out
);
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      mtrx_out[3:0] <= 4'hF;
    end else begin
      if (sel_btns == sel_dpad) begin
        mtrx_out[3:0] <= 4'hF;
      end else if (sel_btns == 0) begin
        mtrx_out[3:0] <= (~(pmoda[3:0]));
      end else begin
        mtrx_out[3:0] <= (~(pmoda[7:4]));
      end
    end
  end

endmodule // Joypad

`default_nettype wire