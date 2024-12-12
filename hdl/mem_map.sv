`timescale 1ns / 1ps
`default_nettype none

module MemMap(
  input wire clk_in,
  input wire rst_in,

  input wire mclock_in,

  input wire [7:0] pmoda,

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
  output logic [7:0] wx_out,
  // PPU Direct access to OAM memory
  input wire [15:0] oam_addr_in,
  input wire [7:0] oam_data_out
);
  // Hardware Registers (https://gbdev.io/pandocs/Hardware_Reg_List.html)
  logic [7:0] joypad_reg;
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

  // Assign PPU helper-outputs to registers
  assign lcdc_out = lcdc_reg;
  assign stat_out = lcds_reg;
  assign scy_out = scy_reg;
  assign scx_out = scx_reg;
  assign lyc_out = lyc_reg;
  assign bgp_out = bgp_reg;
  assign obp0_out = obp0_reg;
  assign obp1_out = obp1_reg;
  assign wy_out = wy_reg;
  assign wx_out = wx_reg;

  Joypad jp(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .sel_btns(joypad_reg[5]),
    .sel_dpad(joypad_reg[4]),
    .pmoda(pmoda),
    .mtrx_out(joypad_reg[3:0])
  );

  // M-Cycle helper
  logic prev_mclock_value;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      prev_mclock_value <= 0;
      lcdc_reg <= 0;
      lcds_reg <= 0;
      scy_reg <= 0;
      scx_reg <= 0;
      obp0_reg <= 0;
      obp1_reg <= 0;
      wy_reg <= 0;
      wx_reg <= 0;
      int_reg <= 0;
      ppu_bram_out <= 0;
      ppu_bram_out <= 0;
    end else begin
      prev_mclock_value <= mclock_in;
      // CPU (runs every M-Cycle)
      if ((prev_mclock_value == 0) && (prev_mclock_value == 1)) begin
        if (is_in_reg(cpu_addr_in)) begin
          if (cpu_data_writing) begin
            case (cpu_addr_in)
              16'hFF00: joypad_reg[5:4] <= cpu_data_in[5:4];
              16'hFF40: lcdc_reg <= cpu_data_in;
              16'hFF41: lcds_reg <= cpu_data_in;
              16'hFF42: scy_reg <= cpu_data_in;
              16'hFF43: scx_reg <= cpu_data_in;
              16'hFF45: lyc_reg <= cpu_data_in;
              16'hFF47: bgp_reg <= cpu_data_in;
              16'hFF48: obp0_reg <= cpu_data_in;
              16'hFF49: obp1_reg <= cpu_data_in;
              16'hFF4A: wy_reg <= cpu_data_in;
              16'hFF4B: wx_reg <= cpu_data_in;
              16'hFFFF: int_reg <= cpu_data_in;
            endcase
          end else begin
            case (cpu_addr_in)
              16'hFF00: cpu_data_out <= joypad_reg;
              16'hFF40: cpu_data_out <= lcdc_reg;
              16'hFF41: cpu_data_out <= lcds_reg;
              16'hFF42: cpu_data_out <= scy_reg;
              16'hFF43: cpu_data_out <= scx_reg;
              16'hFF45: cpu_data_out <= lyc_reg;
              16'hFF47: cpu_data_out <= bgp_reg;
              16'hFF48: cpu_data_out <= obp0_reg;
              16'hFF49: cpu_data_out <= obp1_reg;
              16'hFF4A: cpu_data_out <= wy_reg;
              16'hFF4B: cpu_data_out <= wx_reg;
              16'hFFFF: cpu_data_out <= int_reg;
              default: cpu_data_out <= 16'h0000;
            endcase
          end
        end else if (is_in_ram(cpu_addr_in)) begin
          // BRAM module handles conditionally writing
          if (cpu_data_writing) begin
            cpu_data_out <= 16'h0000;
          end else begin
            cpu_data_out <= cpu_bram_out;
          end
        end else begin
          cpu_data_out <= 16'h0000;
        end
      end
      // PPU (timing is handled by PPU, so runs every clock cycle)

    end
  end

  // BRAM Helpers
  logic [7:0] ppu_bram_out;
  logic [7:0] cpu_bram_out;

  // A -> CPU, B -> PPU
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8),                       // Specify RAM data width
    .RAM_DEPTH(65536),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    .INIT_FILE("")                        // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) working_mem (
    .addra(cpu_addr_in),   // Port A address bus, width determined from RAM_DEPTH
    .addrb(ppu_addr_in),   // Port B address bus, width determined from RAM_DEPTH
    .dina(cpu_data_in),     // Port A RAM input data, width determined from RAM_WIDTH
    .dinb(0),     // Port B RAM input data, width determined from RAM_WIDTH
    .clka(clk_in),     // Port A clock
    .clkb(clk_in),     // Port B clock
    .wea(wea),       // Port A write enable
    .web(0),       // Port B write enable
    .ena(1),       // Port A RAM Enable, for additional power savings, disable port when not in use
    .enb(1),       // Port B RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),     // Port A output reset (does not affect memory contents)
    .rstb(rst_in),     // Port B output reset (does not affect memory contents)
    .regcea(1), // Port A output register enable
    .regceb(1), // Port B output register enable
    .douta(cpu_bram_out),   // Port A RAM output data, width determined from RAM_WIDTH
    .doutb(ppu_bram_out)    // Port B RAM output data, width determined from RAM_WIDTH
  );

endmodule // MemMap

function is_in_ram;
  input [15:0] addr;
  begin
    is_in_ram =
      ((addr >= 16'h0000) && (addr <= 16'hDFFF)) || // ROM, VRAM, WRAM
      ((addr >= 16'hFE00) && (addr <= 16'hFE9F)) || // OAM
      ((addr >= 16'hFF80) && (addr <= 16'hFFFE)); // HRAM
  end
endfunction

function is_in_reg;
  input [15:0] addr;
  begin
    is_in_reg = ((addr >= 16'hFF00) && (addr <= 16'hFF7F));
  end
endfunction