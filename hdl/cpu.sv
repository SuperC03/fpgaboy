`timescale 1ns / 1ps
`default_nettype none

module cpu (
  // Standard clock and reset signals.
  input wire clk_in,
  input wire rst_in,

  // M-cycle clock (CPU only operates in m-cycles)
  input wire mclk_in,

  // Address fed to `mem_map`
  output logic [15:0] addr_bus,

  // Value returned from `mem_map` based on `addr_bus`
  input logic [7:0] mem_in,

  // Value to be written to memory based on `addr_bus` (only when `mem_write` is high)
  output logic [7:0] mem_out,
  output logic mem_write
);
  
endmodule // cpu

`default_nettype wire