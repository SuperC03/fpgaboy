
`timescale 1ns / 1ps
`default_nettype none

module PixelProcessingUnit(
    // Standard clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle and M-cycle clocks.
    input wire tclk_in,
    input wire mclk_in,
    
    // The LCDC and STAT registers | $FF40 and $FF41.
    input wire [7:0] LCDC_in,
    input wire [7:0] STAT_in,
    // The SCY and SCX registers | $FF42 and $FF43.
    input wire [7:0] SCY_in,
    input wire [7:0] SCX_in,
    // Exposing the LY register | $FF44.
    output logic [7:0] LY_out,
    // LYC register | $FF45.
    input wire [7:0] LYC_in,
    // The BGP, OBP0, and OBP1 registers | $FF47, $FF48, and $FF49.
    input wire [7:0] BGP_in,
    input wire [7:0] OBP0_in,
    input wire [7:0] OBP1_in,
    // The WY and WX registers | $FF4A and $FF4B.
    input wire [7:0] WY_in,
    input wire [7:0] WX_in,

    // The data requested from memory.
    output logic [15:0] addr_out,
    input wire [7:0] data_in,
    input wire data_valid_in,
    // The data to be output to the LCD.
    output logic pixel_out,
    // The mode of the PPU.
    output logic [1:0] mode_out,
    // The LY = LYC signal.
    output logic ly_eq_lyc_out
);
    // Enum for the different states of the PPU.
    typedef enum logic[1:0] {HBlank=0, VBlank=1, OAMScan=2, Draw=3} PPUState;
    PPUState state;

    // The LY register, which scanline we are on.
    localparam VISIBLE_SCANLINES = 144;
    localparam VBLANK_SCANLINES = 10;
    localparam TOTAL_SCANLINES = VISIBLE_SCANLINES + VBLANK_SCANLINES;
    logic [$clog2(TOTAL_SCANLINES)-1:0] LY;
    // The X register, which pixel we are on.
    localparam X_MAX = 160;
    logic [$clog2(X_MAX)-1:0] X;
    logic pixel_pushed;
    evt_counter #(.MAX_COUNT(X_MAX)) xCounter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(pixel_pushed),
        .count_out(X)
    );
    // Keeps track of the number of T-cycles elapsed.
    localparam T_MAX = 456;
    logic [$clog2(T_MAX)-1:0] T;
    evt_counter #(.MAX_COUNT(T_MAX)) tCounter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(tclk_in),
        .count_out(T)
    );
    // Number of T-Cycles needed to scan a sprite.
    localparam NUM_SPRITES = 40;
    localparam SPRITE_T_CYCLES = 2;
    localparam OAM_SCAN_T_CYCLES = NUM_SPRITES * SPRITE_T_CYCLES;

    // Centralized state machine for the PPU.
    always_ff @(posedge clk_in) begin
        // State evolution
        case (state)
            ///@brief All 40 sprites are scanned in OAM, 2 T-cycles each.
            OAMScan: begin
                if (T == $clog2(T_MAX)'(OAM_SCAN_T_CYCLES-1) && tclk_in) begin
                    state <= Draw;
                end
            end
            Draw: begin
                ///@brief 160 pixels are drawn, variable T-cycles.
                if (X == $clog2(X_MAX)'(X_MAX-1) && pixel_pushed) begin
                    state <= HBlank;
                end
            end
            /**
            * @brief    HBlank portion of the scanline; for syncing pads to 
            *           456 T-cycles.
            */
            HBlank: begin
                if (T == $clog2(T_MAX)'(T_MAX-1) && tclk_in) begin
                    if (LY == $clog2(TOTAL_SCANLINES)'(VISIBLE_SCANLINES-1)) begin
                        state <= VBlank;
                    end else begin
                        state <= OAMScan;
                    end
                end
            end
            /**
            * @brief    VBlank portion of the scanline; for syncing and 10 
            *           scanlines of VRAM and OAM access.
            */
            VBlank: begin
                if (T == $clog2(T_MAX)'(T_MAX-1) && tclk_in) begin
                    if (LY == $clog2(TOTAL_SCANLINES)'(TOTAL_SCANLINES-1)) begin
                        state <= OAMScan;
                        LY <= $clog2(TOTAL_SCANLINES)'(0);
                    end else begin
                        LY <= LY + $clog2(TOTAL_SCANLINES)'(1);
                    end
                end
            end
        endcase
    end

    // Current sprite being examined.
    logic [$clog2(NUM_SPRITES)-1:0] sprite;
    assign sprite = T[$clog2(NUM_SPRITES):1];
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
        .mclk_in(mclk_in),

        .LY_in(LY),
        .tall_sprite_mode_in(LCDC_in[2]),

        .sprite_in(sprite),
        .data_in(data_in),
        .data_valid_in(data_valid_in),
        
        .parity_in(T[0]),

        .addr_out(addr_out),
        .add_sprite_out(add_sprite)
    );

    // Scans the Object Attribute Memory for relevant sprites.
    always_ff @(posedge tclk_in) begin
        if (state == OAMScan) begin
            // Scans a new sprite from OAM every 2 T-cycles.
            if (add_sprite) begin
                sprite_buffer[n_sprites] <= data_in;
            end
        end
    end

    // Output the PPU-exposed signals.
    assign LY_out = LY;
    assign mode_out = state;
    assign ly_eq_lyc_out = (LY == LYC_in);
endmodule


module OAMScanner #(
    parameter TOTAL_SCANLINES = 154,
    parameter NUM_SPRITES = 40,
    parameter BUFFER_MAX = 10
) (
    // Standard clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T and M-cycle clocks.
    input wire tclk_in,
    input wire mclk_in,

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
                y_res <= 1'b0;
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
                add_sprite_out <= 1'b0;
            end
        end
    end
endmodule


module PixelFetcher #(
    parameter X_MAX = 160
) (
    // Standard clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle clock.
    input wire tclk_in,

    // Access to the internal X position counter.
    input wire [$clog2(X_MAX)-1:0] X_in,
    // Wire to tell the fetcher has completed a pixel push to LCD.
    output wire advance_X_out    
);
    // Defines the 4 states that takes 2 T-cycles each.
    typedef enum logic[1:0] {
        FetchTileNum = 0, 
        FetchTimeDataLow = 1, 
        FetchTileDataHigh = 2, 
        Push2FIFO = 3
    } FetcherState;


endmodule

`default_nettype wire