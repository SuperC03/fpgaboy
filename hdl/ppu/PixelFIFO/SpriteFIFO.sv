`default_nettype none

/**
* BackgroundFIFO module which is self-supplied with data from the BackgroundFetcher
* module. This module is responsible for storing the background pixels in a FIFO
* buffer for the PPU to read from.
*/
module SpriteFIFO #(
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
    // Wire telling the BackgroundFIFO that a sprite has been hit and to stop
    // its own fetching.
    output logic sprite_detected_out,

    // Wire pushing a new pixel to the LCD.
    output logic [1:0] pixel_out,
    output logic pixel_valid_out,

    /***************************************************************************
    * @note BackgroundFetcher signals.
    ***************************************************************************/
    // The internal X and Y position counters for screen pixel rendering coords.
    input wire [$clog2(X_MAX)-1:0] X_in,

    // The screen position registers relative to the background.
    input wire [7:0] SCY_in,
    input wire [7:0] SCX_in,

    // The sprite enable flag.
    input wire sprite_ena_in,
    // Access to the sprite buffer.
    input wire [17:0] sprite_buffer_in [9:0],
    // Access to the tall-sprite mode register.
    input wire tall_sprite_mode_in,

    // Signal to rummage into the OAM and fetch the sprite flag.
    output logic [15:0] flag_addr_request_out,
    // Return signal for the sprite flags.
    input wire [7:0] sprite_flags_in,
    input wire valid_flags_in,
    // Signal exposing the sprite palette choice for the FIFO.
    output logic dmg_pallete_out,
    // The priority of the sprite over the background.
    output logic sprite_priority_out,

    // Whether the background FIFO is fetching data.
    input wire mem_free,
    // The address to fetch data from memory.
    output logic [15:0] addr_out,
    // The valid request signal to fetch data from memory.
    output logic addr_valid_out,
    // The data fetched from memory.
    input wire [7:0] data_in,
    // The data valid signal.
    input wire data_valid_in
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

    // The sprite position in the buffer.
    logic [5:0] sprite_pos;
    // The SpriteFetcher module will supply the SpriteFIFO with pixels.
    logic [1:0] row [7:0];
    logic valid_row;
    SpriteFetcher #(
        .X_MAX(X_MAX),
        .TOTAL_SCANLINES(TOTAL_SCANLINES)
    ) sprite_fetcher (
        // Standard clock and reset signals.
        .clk_in(clk_in),
        .rst_in(rst_in),

        // The T-cycle clock.
        .tclk_in(tclk_in),

        // Access to the internal X position counter.
        .X_in(X_in),
        // Access to the tall-sprite mode register.
        .tall_sprite_mode_in(tall_sprite_mode_in),

        // Access to the SCY and SCX registers.
        .SCY_in(SCY_in),
        .SCX_in(SCX_in),

        // Whether sprite mode is enabled.
        .sprite_ena_in(sprite_ena_in),
        // Access to the sprite registers.
        .sprite_buffer_in(sprite_buffer_in),
        // Whether we've detected a sprite.
        .sprite_detected_out(sprite_detected_out),

        // Signal to rummage into the OAM and fetch the sprite flag.
        .flag_addr_request_out(flag_addr_request_out),
        // Return signal for the sprite flags.
        .sprite_flags_in(sprite_flags_in),
        .valid_flags_in(valid_flags_in),
        // Signal exposing the sprite palette choice for the FIFO.
        .dmg_pallete_out(dmg_pallete_out),
        // The priority of the sprite over the background.
        .sprite_priority_out(sprite_priority_out),

        // Whether the background FIFO is fetching data.
        .mem_free(mem_free),
        // Wire requesting a tile row from memory.
        .addr_out(addr_out),
        // Valid request to fetch data from memory.
        .addr_valid_out(addr_valid_out),
        // Data fetched from memory.
        .data_in(data_in),
        // Whether the data fetched is valid.
        .data_valid_in(data_valid_in),

        // Whether the Sprite FIFO is empty.
        .sprite_fifo_empty_in(wr_en),
        // Pixels to push to the Background FIFO.
        .valid_pixels_out(valid_row),
        .pixels_out(row)
    );
    // Pipeline waiting for the pixel push; flag request pipeline and flag-derived
    // items take 3 cycles but it is irrelevant to the FIFO because its supply happens
    // 2 T-cycles after the sprite is detected and the flag is requested.
    logic tclk_fetcher_delay;
    Pipeline #(
        .WIDTH(1),
        .STAGES(1)
    ) tclkFetcherPipeline (
        .clk_in(tclk_in),
        .rst_in(rst_in),
        .data_in(sprite_detected_out),
        .data_out(tclk_fetcher_delay)
    );

    // We're implicitly guaranteed that we will have the sprite flags before this
    // portion of the hardware can activate as valid_row lights up 2 T-cycles after
    // sprite_detected_out.
    always_ff @(posedge clk_in) begin
        // Writes to the FIFO.
        if (tclk_fetcher_delay && valid_row && read) begin
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