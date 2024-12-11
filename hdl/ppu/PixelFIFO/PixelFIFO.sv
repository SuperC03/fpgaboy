`timescale 1ns / 1ps
`default_nettype none

module PixelFIFO #(
    parameter X_MAX = 160,
    parameter TOTAL_SCANLINES = 154,
    parameter WIDTH = 8,
    parameter DEPTH = 16
) (
    // Global clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle clock.
    input wire tclk_in,

    // Wire telling the LCD there's a new pixel to read.
    output logic [1:0] pixel_out,
    output logic pixel_valid_out,

    // Access to the screen position registers.
    input wire [7:0] SCY_in,
    input wire [7:0] SCX_in,

    // Access to the internal pixel-rendering position counters.
    input wire [$clog2(X_MAX)-1:0] X_in,
    input wire [$clog2(TOTAL_SCANLINES)-1:0] Y_in,
    // Access to the LCDC register.
    input wire [7:0] LCDC_in,

    // Handles data requests.
    output logic [15:0] addr_out,
    output logic addr_valid_out,
    input wire [7:0] data_in,
    input wire data_valid_in,

    // Palettes.
    input wire [7:0] BGP_in,
    input wire [7:0] OBP0_in,
    input wire [7:0] OBP1_in,

    /***************************************************************************
    * @note BackgroundFIFO signals.
    ***************************************************************************/
    // Wire for WY condition.
    input wire WY_cond_in,
    // Wires for the window position registers.
    input wire [7:0] WY_in,
    input wire [7:0] WX_in,
    /***************************************************************************
    * @note SpriteFIFO signals.
    ***************************************************************************/
    // Access to the sprite buffer.
    input wire [17:0] sprite_buffer_in [9:0],
    // Handles OAM requests.
    output logic [15:0] flag_addr_request_out,
    output logic flag_request_out,
    input wire [7:0] sprite_flags_in,
    input wire valid_flags_in
);
    // Signals from the background FIFO.
    logic [1:0] bg_pixel;
    logic bg_pixel_valid;
    logic [15:0] bg_addr_out;
    logic bg_addr_valid;
    logic bg_data_valid;
    logic bg_mem_hog;
    // Signals from the sprite FIFO.
    logic sprite_detected;
    logic [1:0] obj_pixel;
    logic obj_pixel_valid;
    logic [15:0] obj_addr_out;
    logic obj_addr_valid;
    logic obj_data_valid;
    logic obj_palette;
    logic sprite_priority;
    // Assigns the bg_data_valid signal iff the bg owns the memory.
    always_comb begin
        bg_data_valid = data_valid_in && !sprite_detected;
    end

    // Signal to wait for the sprite FIFO to finish.
    logic pause;
    assign pause = sprite_detected;

    // Pipeline to delay the SpriteFIFO by 1 cycle.
    logic tick_spriteFIFO;
    Pipeline #(
        .WIDTH(1),
        .STAGES(1)
    ) sprite_delay (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(tclk_in),
        .data_out(tick_spriteFIFO)
    );

    BackgroundFIFO #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .X_MAX(X_MAX),
        .TOTAL_SCANLINES(TOTAL_SCANLINES)
    ) background_fetcher (
        // Global clock and reset signals.
        .clk_in(clk_in),
        .rst_in(rst_in),

        // The T-cycle clock.
        .tclk_in(tclk_in),

        // Wire requesting a new pixel from the FIFO. Stops when PPU is stopped.
        .rd_en(LCDC_in[7] && !pause),

        // Wire pushing a new pixel to the LCD.
        .pixel_out(bg_pixel),
        .pixel_valid_out(bg_pixel_valid),

        /***************************************************************************
        * @note BackgroundFetcher signals.
        ***************************************************************************/
        // The internal X and Y position counters for screen pixel rendering coords.
        .X_in(X_in),
        .Y_in(Y_in),

        // The screen position registers relative to the background.
        .SCY_in(SCY_in),
        .SCX_in(SCX_in),
        // The background map to use for the background.
        .background_map_in(LCDC_in[3]),

        // The window position registers relative to the background.
        .WY_in(WY_in),
        .WX_in(WX_in),
        // The WY condition to determine if the window is enabled.
        .WY_cond_in(WY_cond_in),
        // The window map to use for the window.
        .window_map_in(LCDC_in[6]),
        // The window enable flag.
        .window_ena_in(LCDC_in[5]),

        // The addressing mode to use for accessing background tiles.
        .addressing_mode_in(LCDC_in[4]),
        // The address to fetch data from memory.
        .addr_out(bg_addr_out),
        // The valid request signal to fetch data from memory.
        .addr_valid_out(bg_addr_valid),
        // The data fetched from memory.
        .data_in(data_in),
        // The data valid signal.
        .data_valid_in(bg_data_valid),

        // Wire telling the BackgroundFIFO that a sprite has been hit and to stop
        // its own fetching.
        .sprite_hit_in(sprite_detected),
        // Wire letting the PixelFIFO know that the BackgroundFIFO is running.
        .mem_busy_out(bg_mem_hog)
    );

    SpriteFIFO #(
        .X_MAX(X_MAX),
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) sprite_fifo (
        // Global clock and reset signals.
        .clk_in(clk_in),
        .rst_in(rst_in),

        // The T-cycle clock.
        .tclk_in(tick_spriteFIFO),

        // Wire requesting a new pixel from the FIFO.
        .rd_en(LCDC_in[7] && !pause),
        // Wire telling the BackgroundFIFO that a sprite has been hit and to stop
        // its own fetching.
        .sprite_detected_out(sprite_detected),

        // Wire pushing a new pixel to the LCD.
        .pixel_out(obj_pixel),
        .pixel_valid_out(obj_pixel_valid),

        /***************************************************************************
        * @note BackgroundFetcher signals.
        ***************************************************************************/
        // The internal X and Y position counters for screen pixel rendering coords.
        .X_in(X_in),

        // The sprite enable flag.
        .sprite_ena_in(LCDC_in[1]),
        // Access to the sprite buffer.
        .sprite_buffer_in(sprite_buffer_in),
        // Access to the tall-sprite mode register.
        .tall_sprite_mode_in(LCDC_in[2]),

        // Signal to rummage into the OAM and fetch the sprite flag.
        .flag_addr_request_out(flag_addr_request_out),
        .flag_request_out(flag_request_out),
        // Return signal for the sprite flags.
        .sprite_flags_in(sprite_flags_in),
        .valid_flags_in(valid_flags_in),
        // Signal exposing the sprite palette choice for the FIFO.
        .dmg_palette_out(obj_palette),
        // The priority of the sprite over the background.
        .sprite_priority_out(sprite_priority),

        // Whether the background FIFO is fetching data.
        .mem_free(!bg_mem_hog),
        // The address to fetch data from memory.
        .addr_out(obj_addr_out),
        // The valid request signal to fetch data from memory.
        .addr_valid_out(obj_addr_valid),
        // The data fetched from memory.
        .data_in(data_in),
        // The data valid signal.
        .data_valid_in(obj_data_valid)
    );

    // Memory request arbitration.
    always_comb begin
        if (bg_mem_hog) begin
            addr_out = bg_addr_out;
            addr_valid_out = bg_addr_valid;
            obj_data_valid = 1'b0;
            bg_data_valid = data_valid_in;
        end else if (sprite_detected) begin
            addr_out = obj_addr_out;
            addr_valid_out = obj_addr_valid;
            bg_data_valid = 1'b0;
            obj_data_valid = data_valid_in;
        end else begin
            addr_out = 16'h0;
            addr_valid_out = 1'b0;
            obj_data_valid = 1'b0;
            bg_data_valid = 1'b0;
        end
    end

    // Palette resolution.
    logic [2:0] bg_palette_position;
    logic [2:0] obj_palette_position;
    always_comb begin
        bg_palette_position = 3'(bg_pixel) << 1;
        obj_palette_position = 3'(bg_pixel) << 1;
    end

    logic [1:0] bg_pixel_palettized;
    logic [1:0] obj_pixel_palettized;
    assign bg_pixel_palettized = LCDC_in[0] ? 2'b0 : (BGP_in >> $unsigned(bg_palette_position));
    assign obj_pixel_palettized = obj_palette ?
        (OBP1_in >> $unsigned(obj_palette_position)) : (OBP0_in >> $unsigned(obj_palette_position));
    
    always_comb begin
        if (bg_pixel_valid && obj_pixel_valid) begin
            if (sprite_priority) begin
                pixel_out = obj_pixel_palettized;
                pixel_valid_out = obj_pixel_valid;
            end else begin
                if (bg_pixel_palettized == 2'b0) begin
                    pixel_out = obj_pixel_palettized;
                    pixel_valid_out = obj_pixel_valid;
                end else begin
                    pixel_out = bg_pixel_palettized;
                    pixel_valid_out = bg_pixel_valid;
                end
            end
        end else if (bg_pixel_valid) begin
            pixel_out = bg_pixel_palettized;
            pixel_valid_out = bg_pixel_valid;
        end else if (obj_pixel_valid) begin
            pixel_out = obj_pixel_palettized;
            pixel_valid_out = obj_pixel_valid;
        end else begin
            pixel_out = 2'b0;
            pixel_valid_out = 1'b0;
        end
    end
endmodule

`default_nettype wire