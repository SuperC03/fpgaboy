import sys
import os

import gen_funcs as gf

def template(input):
  return f'''// Autogenerated by cpu_gen.py - DO NOT EDIT  

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


  // Unofficial Accumulator registers 
  logic [15:0] n16_reg;

  // CPU Registers
  logic [15:0] af_reg; // Accumulator and Flags registers
  logic [15:0] bc_reg; // B and C registers
  logic [15:0] de_reg; // D and E registers
  logic [15:0] hl_reg; // H and L registers
  logic [15:0] sp_reg; // Stack Pointer register
  logic [15:0] pc_reg; // Program Counter register

  always_ff @(clk_in) begin
    if (rst_in) begin
      af_reg <= 0;
      bc_reg <= 0;
      de_reg <= 0;
      hl_reg <= 0;
      sp_reg <= 0;
      pc_reg <= 0;
    end else begin
      case (param)
        {input}
      endcase
    end
  end

endmodule // cpu

`default_nettype wire
'''



def main():
  path = sys.argv[1]
  if not path or path == "":
    raise Exception("Please specify a file path")

  with open(os.path.basename(path), "w") as file:
    file.write(template(""))
    print("Wrote to %s" % path)

main()