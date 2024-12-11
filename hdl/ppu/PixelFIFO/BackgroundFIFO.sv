`default_nettype none

/**
* BackgroundFIFO module which is self-supplied with data from the BackgroundFetcher
* module. This module is responsible for storing the background pixels in a FIFO
* buffer for the PPU to read from.
*/
module BackgroundFIFO #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter X_MAX = 160,
    parameter TOTAL_SCANLINES = 154
) (
    // Global clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle clock.
    input wire tclk_in,

    // Wire requesting a new pixel from the FIFO.
    input wire rd_en,

    // Wire pushing a new pixel to the LCD.
    output logic [1:0] pixel_out,
    output logic pixel_valid_out,

    /***************************************************************************
    * @note BackgroundFetcher signals.
    ***************************************************************************/
    // The internal X and Y position counters for screen pixel rendering coords.
    input wire [$clog2(X_MAX)-1:0] X_in,
    input wire [$clog2(TOTAL_SCANLINES)-1:0] Y_in,

    // The screen position registers relative to the background.
    input wire [7:0] SCY_in,
    input wire [7:0] SCX_in,
    // The background map to use for the background.
    input wire background_map_in,

    // The window position registers relative to the background.
    input wire [7:0] WY_in,
    input wire [7:0] WX_in,
    // The WY condition to determine if the window is enabled.
    input wire WY_cond_in,
    // The window map to use for the window.
    input wire window_map_in,
    // The window enable flag.
    input wire window_ena_in,

    // The addressing mode to use for accessing background tiles.
    input wire addressing_mode_in,
    // The address to fetch data from memory.
    output logic [15:0] addr_out,
    // The valid request signal to fetch data from memory.
    output logic addr_valid_out,
    // The data fetched from memory.
    input wire [7:0] data_in,
    // The data valid signal.
    input wire data_valid_in,

    // Wire telling the BackgroundFIFO that a sprite has been hit and to stop
    // its own fetching.
    input wire sprite_hit_in,
    // Wire letting the PixelFIFO know that the BackgroundFIFO is running.
    output logic mem_busy_out
);
    logic [WIDTH-1:0] mem [DEPTH-1:0];
    logic [$clog2(DEPTH)-1:0] rd_ptr;
    logic [2:0] wr_ptr;
    logic [3:0] occupancy;

    logic read;
    logic wr_en;
    always_comb begin
        wr_en = occupancy <= $floor(DEPTH / 2);
        read = rd_en && (occupancy > 0);
    end

    // Pipeline to delay the tclk signal by 1 cycle.
    logic tclk_fetcher_delay;
    Pipeline #(
        .WIDTH(1),
        .STAGES(1)
    ) tclkFetcherPipeline (
        .clk_in(tclk_in),
        .rst_in(rst_in),
        .data_in(sprite_hit_in),
        .data_out(tclk_fetcher_delay)
    );
    // The BackgroundFetcher module will supply the BackgroundFIFO with pixels.
    logic [1:0] row [7:0];
    logic valid_row;
    BackgroundFetcher #(
        .X_MAX(X_MAX),
        .TOTAL_SCANLINES(TOTAL_SCANLINES)
    ) bg_fetcher (
        // Standard clock and reset signals.
        .clk_in(clk_in),
        .rst_in(rst_in),
        // The T-cycle clock.
        .tclk_in(tclk_in),
        // Access to the internal X position counter.
        .X_in(X_in),
        // Access to the internal Y position counter.
        .Y_in(Y_in),

        // Access to the SCY and SCX registers.
        .SCY_in(SCY_in),
        .SCX_in(SCX_in),
        // Flag to determine which background map to use for the background.
        .background_map_in(background_map_in),

        // Access to the WY and WX registers.
        .WY_in(WY_in),
        .WX_in(WX_in),
        // Determines if the WY condition is met.
        // https://gbdev.io/pandocs/Scrolling.html#ff4aff4b--wy-wx-window-y-position-x-position-plus-7
        .WY_cond_in(WY_cond_in),
        // Flag to determine which background map to use for the window.
        .window_map_in(window_map_in),
        // Flag to determine if the window is enabled.
        .window_ena_in(window_ena_in),

        // Determines which addressing scheme to use for accessing background tiles.
        .addressing_mode_in(addressing_mode_in),

        // Wire requesting a tile row from memory.
        .addr_out(addr_out),
        // Valid request to fetch data from memory.
        .addr_valid_out(addr_valid_out),
        // Data fetched from memory.
        .data_in(data_in),
        // Whether the data fetched is valid.
        .data_valid_in(data_valid_in),

        // Whether the background FIFO is empty.
        .bg_fifo_empty_in(read),
        // Pixels to push to the Background FIFO.
        .valid_pixels_out(valid_row),
        .pixels_out(row),

        // Whether a sprite has been hit and to stop fetching.
        .sprite_hit_in(sprite_hit_in),
        // Whether the BackgroundFIFO is busy.
        .mem_busy_out(mem_busy_out)
    );

    always_ff @(posedge clk_in) begin
        // Writes to the FIFO.
        if (tclk_fetcher_delay && valid_row && read) begin
            /** @note
            * Horizontal flipping of BG is a CGB only feature:
            * https://gbdev.io/pandocs/pixel_fifo.html
            * https://gbdev.io/pandocs/Tile_Maps.html#bg-map-attributes-cgb-mode-only
            */
            for (int i = 0; i < 8; i++) begin
                mem[wr_ptr + i] <= row[i];
            end
            wr_ptr <= wr_ptr + $clog2(DEPTH)'('h8);
        end

        // Reads from the FIFO.
        if (tclk_fetcher_delay && valid_row && read) begin
            pixel_out <= mem[rd_ptr];
            pixel_valid_out <= 1'b1;
            rd_ptr <= (rd_ptr >= $clog2(DEPTH)'(DEPTH - 1)) ? 
                    $clog2(DEPTH)'('h0) : rd_ptr + $clog2(DEPTH)'('h1);
        end else begin
            pixel_valid_out <= 1'b0;
        end
    end
endmodule

`default_nettype wire