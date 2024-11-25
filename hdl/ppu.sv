
`timescale 1ns / 1ps
`default_nettype none

module PixelProcessingUnit(
    input wire clk_in,
    input wire rst_in
);
    // Enum for the different states of the PPU.
    typedef enum logic[1:0] {HBlank=0, VBlank=1, OAMScan=2, Draw=3} PPUState;
    PPUState state;

    // The LY register, which scanline we are on.
    logic [$clog2(144 + 10)-1:0] LY;
    // The X register, which pixel we are on.
    logic [$clog2(160)-1:0] X;
    // Keeps track of the number of T-cycles elapsed.
    logic [$clog2(456)-1:0] T;
    evt_counter #(.MAX_COUNT(456)) tCounter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(clk_in),
        .count_out(T)
    );
    // The buffer of sprites to draw.
    logic [3:0][8:0] spriteBuffer [9:0];

    always_ff @(posedge clk_in) begin
        case (state)
            OAMScan: begin
                // Do OAM scan stuff. 

                ///@brief end of OAM scan, move to Draw.
                if (T == 79) begin
                    state <= Draw;
                end
            end
            Draw: begin
                // Do draw stuff.

                ///@brief end of scanline, move to HBlank.
                if (X == 159) begin
                    state <= HBlank;
                end
            end
            HBlank: begin
                ///@brief HBlank portion of the scanline; for syncing.
                ///@note All fetcher and FIFO operations are done stopped.
                ///@note Resets all registers to prep for the next scanline.

                ///@brief end of scanline, evolve.
                if (T == 455) begin
                    if (LY == 143) begin
                        state <= VBlank;
                    end else begin
                        state <= OAMScan;
                    end
                    X <= 0;
                end
            end
            VBlank: begin
                ///@brief VBlank portion of the scanline; for syncing.
                ///@note All fetcher and FIFO operations are done stopped.
                ///@note Resets all registers to prep for the next scanline.

                ///@brief end of VBlank, move to OAMScan.
                if (T == 455) begin
                    if (LY == 153) begin
                        state <= OAMScan;
                        LY <= 0;
                    end else begin
                        LY <= LY + 1;
                    end
                end
            end
        endcase
    end


endmodule

`default_nettype wire