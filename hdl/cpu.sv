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

  logic [7:0] a_reg; // Accumulator Register
  logic [7:0] b_reg; // B Register
  logic [7:0] c_reg; // C Register
  logic [7:0] d_reg; // D Register
  logic [7:0] e_reg; // E Register
  logic [7:0] f_reg; // Flags Register
  logic [7:0] h_reg; // H Register
  logic [7:0] l_reg; // L Register
  logic [7:0] sp_reg; // Stack Pointer Register
  logic [7:0] pc_reg; // Program Counter Register

  // Current OpCode being executed (default is 0x00, NOP, in the unprefixed set)
  logic [7:0] current_code;

  // Flag if the current code was prefixed with 
  logic cb_prefixed;

  // Flag if the next code should be retrived (allowing for overlap command execution)
  logic prefetch_next_code;

  always_ff @(clk_in) begin
    if (rst_in) begin
      a_reg <= 0;
      b_reg <= 0;
      b_reg <= 0;
      c_reg <= 0;
      d_reg <= 0;
      e_reg <= 0;
      f_reg <= 0;
      h_reg <= 0;
      l_reg <= 0;
      sp_reg <= 0;
    end else begin
      case (param)
        
        default: 
      endcase
    end
  end

  
endmodule // cpu

`default_nettype wire