`default_nettype none

module PixelFIFO #(
    parameter X_MAX = 160,
    parameter TOTAL_SCANLINES = 154,
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

    // Access to the sprite buffer.
    input wire [17:0] sprite_buffer_in [9:0],
    // Handles OAM requests.
    output logic [15:0] flag_addr_request_out,
    output logic flag_request_out,
    // Handles data requests.
    output logic [15:0] addr_out,
    output logic addr_valid_out,
    input wire [7:0] data_in,
    input wire data_valid_in,

    /***************************************************************************
    * @note BackgroundFIFO signals.
    ***************************************************************************/
    // Wire for WY condition.
    input wire WY_cond_in,

);
    // Signals from the background FIFO.
    logic [1:0] bg_pixel;
    logic bg_pixel_valid;
    logic [15:0] bg_addr_out;
    logic bg_addr_valid;
    logic bg_data_valid;
    logic bg_mem_hog;
    // Assigns the bg_data_valid signal iff the bg owns the memory.
    always_comb begin
        bg_data_valid = data_valid_in && !sprite_detected;
    end

    // Signals from the sprite FIFO.
    logic sprite_detected;
    BackgroundFIFO #(
        .X_MAX(X_MAX),
        .TOTAL_SCANLINES(TOTAL_SCANLINES)
    ) background_fetcher (
        // Global clock and reset signals.
        .clk_in(clk_in),
        .rst_in(rst_in),

        // The T-cycle clock.
        .tclk_in(tclk_in),

        // Wire requesting a new pixel from the FIFO. Stops when PPU is stopped.
        .rd_en(LCDC_in[7]),
        // Wire telling the BackgroundFIFO that a sprite has been hit and to stop
        // its own fetching.
        .sprite_hit_in(sprite_detected),

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
        .data_valid_in(bg_data_valid)

        // Wire telling the BackgroundFIFO that a sprite has been hit and to stop
        // its own fetching.
        .sprite_hit_in(sprite_detected),
        // Wire letting the PixelFIFO know that the BackgroundFIFO is running.
        .mem_busy_out(bg_mem_hog)
    );

    SpriteFIFO sprite_fifo (
    );

endmodule

`default_nettype wire