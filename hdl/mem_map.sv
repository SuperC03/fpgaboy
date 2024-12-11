`timescale 1ns / 1ps
`default_nettype none

module MemMap(
  input wire clk_in,
  input wire rst_in,

  input wire mclock_in,

  input wire [15:0] cpu_addr_in,
  input wire [7:0] cpu_data_in,
  input wire cpu_data_writing,
  output logic [7:0] cpu_data_out,

  input wire [15:0] ppu_addr_in,
  output logic [7:0] ppu_data_out,
  input logic [1:0] ppu_mode_in,
  // PPU Direct Access to Registers
  output logic [7:0] lcdc_out,
  output logic [7:0] stat_out,
  output logic [7:0] scy_out,
  output logic [7:0] scx_out,
  input wire [7:0] ly_in,
  output logic [7:0] lyc_out,
  output logic [7:0] bgp_out,
  output logic [7:0] obp0_out,
  output logic [7:0] obp1_out,
  output logic [7:0] wy_out,
  output logic [7:0] wx_out
);
  // Hardware Registers (https://gbdev.io/pandocs/Hardware_Reg_List.html)
  // 0xFF01 - 0xFF02: UNIMPLEMENTED
  // 0xFF04 - 0xFF0F: TODO
  // 0xFF10 - 0xFF3F: UNIMPLEMENTED
  logic [7:0] lcdc_reg; // 0xFF40
  logic [7:0] lcds_reg; // 0xFF41
  logic [7:0] scy_reg; // 0xFF42
  logic [7:0] scx_reg; // 0xFF43
  // 0xFF44: PPU
  logic [7:0] lyc_reg; // 0xFF45
  // 0xFF46: TODO
  logic [7:0] bgp_reg; // 0xFF47
  logic [7:0] obp0_reg; // 0xFF48
  logic [7:0] obp1_reg; // 0xFF49
  logic [7:0] wy_reg; // 0xFF4A
  logic [7:0] wx_reg; // 0xFF4B
  // 0xFF4D - 0xFF77: UNIMPLEMENTED (CGB Only)
  logic [7:0] int_reg; // 0xFFFF



endmodule