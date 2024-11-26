
`timescale 1ns / 1ps
`default_nettype none

module PixelProcessingUnit(
    // Standard clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle clock.
    input wire tclk_in,
    
    // Data bus for memory.
    input wire [7:0] data_in,
    input wire data_valid_in,
    // The LCDC and STAT register updates.
    input wire [7:0] LCDC_in,
    input wire [7:0] STAT_in,
    // The LYC register.
    input wire [7:0] LYC_in,
    
    // The LCDC and STAT register outputs.
    output wire [7:0] LCDC_out,
    output wire [7:0] STAT_out,
    // Data bus requests.
    output wire [15:0] addr_out,
    output wire valid_out
);
    // Enum for the different states of the PPU.
    typedef enum logic[1:0] {HBlank=0, VBlank=1, OAMScan=2, Draw=3} PPUState;
    PPUState state;

    // The LY register, which scanline we are on.
    parameter VISIBLE_SCANLINES = 144;
    parameter VBLANK_SCANLINES = 10;
    parameter TOTAL_SCANLINES = VISIBLE_SCANLINES + VBLANK_SCANLINES;
    logic [$clog2(TOTAL_SCANLINES)-1:0] LY;
    // The X register, which pixel we are on.
    localparam X_MAX = 160;
    logic [$clog2(X_MAX)-1:0] X;
    // Keeps track of the number of T-cycles elapsed.
    localparam T_MAX = 456;
    logic [$clog2(T_MAX)-1:0] T;
    evt_counter #(.MAX_COUNT(T_MAX)) tCounter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(clk_in),
        .count_out(T)
    );

    // The current LCDC and STAT registers.
    logic [7:0] LCDC;
    logic [7:0] STAT;
    // Current sprite being examined.
    localparam NUM_SPRITES = 40;
    logic [$clog2(NUM_SPRITES)-1:0] sprite;
    assign sprite = T[$clog2(NUM_SPRITES)-1:1];
    // Whether or not to add the current sprite to the sprite buffer.
    logic add_sprite;

    // Instantiates the sprite buffer.
    localparam SPRITE_BUFFER_SIZE = 10;
    logic [7:0] sprite_buffer [$clog2(SPRITE_BUFFER_SIZE)-1:0];
    logic [$clog2(SPRITE_BUFFER_SIZE)-1:0] n_sprites;
    // Instantiates the sprite buffer counter.
    evt_counter #(.MAX_COUNT(SPRITE_BUFFER_SIZE+1)) spriteBufferCounter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(add_sprite),
        .count_out(n_sprites)
    );

    // Instantiate the OAM scan module.
    OAMScanner #(
        .TOTAL_SCANLINES(TOTAL_SCANLINES),
        .NUM_SPRITES(NUM_SPRITES),
        .BUFFER_MAX(SPRITE_BUFFER_SIZE)
    ) oamScan (
        .clk_in(clk_in),
        .rst_in(rst_in),

        .tclk_in(tclk_in),
        .LY_in(LY),
        .tall_sprite_mode_in(LCDC[2]),

        .sprite_in(sprite),
        .data_in(data_in),
        .data_valid_in(data_valid_in),
        
        .parity_in(T[0]),

        .addr_out(addr_out),
        .add_sprite_out(add_sprite)
    );

    always_ff @(posedge tclk_in) begin
        //Update the LCDC and STAT registers.
        LCDC <= LCDC_in;
        STAT <= {STAT_in[7:3], 1'(LY == LYC_in), 2'(state)};

        // State evolution
        case (state)
            OAMScan: begin
                // Scans the Object Attribute Memory for relevant sprites.
                // Scans a new sprite from OAM every 2 T-cycles.
                if (add_sprite) begin
                    sprite_buffer[n_sprites] <= data_in;
                end

                

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

    // Output the LCDC and STAT registers.
    assign LCDC_out = LCDC;
    assign STAT_out = STAT;
endmodule


module OAMScanner #(
    parameter TOTAL_SCANLINES = 154,
    parameter NUM_SPRITES = 40,
    parameter BUFFER_MAX = 10
) (
    // Standard clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle clock.
    input wire tclk_in,

    // Access wire to the LY register.
    input wire [$clog2(TOTAL_SCANLINES)-1:0] LY_in,
    // Access to the tall-sprite mode register.
    input wire tall_sprite_mode_in,

    // The sprite number to scan, and the data being supplied by memory.
    input wire [$clog2(NUM_SPRITES)-1:0] sprite_in,
    input wire [7:0] data_in,
    input wire data_valid_in,
    // The number of sprites in the sprite buffer.
    input wire [$clog2(BUFFER_MAX)-1:0] n_sprites,
    // Whether we're receiving Y or X data (if parity == 0, Y; else X).
    input wire parity_in,

    // Determines what address we need to request from the OAM.
    output logic [15:0] addr_out,
    // Determines whether to add the current sprite to the sprite buffer.
    output logic add_sprite_out
);
    // OAM ADDR base.
    logic [15:0] OAMBase = 16'hFE00;
    // Sprite ADDR base.
    logic [15:0] spriteBase = OAMBase + (sprite_in << 2);
    // Request the sprite data according to the parity.
    assign addr_out = {spriteBase[15:1], parity_in};

    // OAM determination is broken up into two parts: Y and X.
    logic y_res;
    // Calculates LY + 16 to see if the sprite is visible.
    logic [$clog2(TOTAL_SCANLINES):0] LY_plus = LY_in + 16;

    // Processes the data from the OAM.
    always_ff @(posedge clk_in) begin
        // Gets in valid data from the memory.
        if (data_valid_in) begin
            // If reading the X data, check if the sprite is visible.
            if (parity_in) begin
                // If the sprite is visible, add it to the sprite buffer.
                /**
                * @note Sprites are not visible if x=0 as the screen X coordinate 
                *       starts at 8 and sprites are 8 pixels wide.
                */
                add_sprite_out <= (data_in > 0) ? y_res && n_sprites < BUFFER_MAX : 1'b0;
                // Resets the y_res signal in preparation for the next sprite.
                y_res <= 0;
            end else begin
                // If reading the Y data, check if the sprite is on the current scanline.
                /**
                * @note The screen starts at y=16 in the sprite coordinate system,
                *       so we need to add 16 to the LY register to get the screen
                *       coordinate.
                */
                y_res <=(data_in <= LY_plus) &&
                // Tall sprites are 16 pixels tall, while short sprites are 8 pixels tall.
                        (LY_plus < y_res + 4'h8 << tall_sprite_mode_in);
                add_sprite_out <= 0;
            end
        end
    end
endmodule

`default_nettype wire