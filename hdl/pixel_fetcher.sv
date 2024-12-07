`default_nettype none

// Fetches the background tiles from memory.
// https://gbdev.io/pandocs/pixel_fifo.html
// https://hacktix.github.io/GBEDG/ppu/#background-pixel-fetching
module BackgroundFetcher #(
    parameter X_MAX = 160,
    parameter TOTAL_SCANLINES = 154
) (
    // Standard clock and reset signals.
    input wire clk_in,
    input wire rst_in,

    // The T-cycle clock.
    input wire tclk_in,

    // Access to the internal X position counter.
    input wire [$clog2(X_MAX)-1:0] X_in,
    // Access to the internal Y position counter.
    input wire [$clog2(TOTAL_SCANLINES)-1:0] Y_in,

    // Access to the SCY and SCX registers.
    input wire [7:0] SCY_in,
    input wire [7:0] SCX_in,
    // Flag to determine which background map to use for the background.
    input wire background_map_in,

    // Access to the WY and WX registers.
    input wire [7:0] WY_in,
    input wire [7:0] WX_in,
    // Determines if the WY condition is met.
    // https://gbdev.io/pandocs/Scrolling.html#ff4aff4b--wy-wx-window-y-position-x-position-plus-7
    input wire WY_cond_in,
    // Flag to determine which background map to use for the window.
    input wire window_map_in,
    // Flag to determine if the window is enabled.
    input wire window_ena_in,

    // Determines which addressing scheme to use for accessing background tiles.
    input wire addressing_mode_in,

    // Wire requesting a tile row from memory.
    output logic [15:0] addr_out,
    // Valid request to fetch data from memory.
    output logic addr_valid_out,
    // Data fetched from memory.
    input wire [7:0] data_in,
    // Whether the data fetched is valid.
    input wire data_valid_in,

    // Whether the background FIFO is empty.
    input wire bg_fifo_empty_in,
    // Pixels to push to the Background FIFO.
    output logic valid_pixels_out,
    output logic [1:0] pixels_out [7:0]
);
    // Defines the 4 states that takes 2 T-cycles each.
    typedef enum logic[1:0] {
        FetchTileNum = 0, 
        FetchTileDataLow = 1, 
        FetchTileDataHigh = 2, 
        Push2FIFO = 3
    } FetcherState;
    FetcherState state;
    // Determines whether or not we are waiting a T-cycle to advance the state.
    logic stall;

    // Internal buffers for the fetcher for output values to hold.
    logic [15:0] addr;
    logic addr_valid;
    logic [1:0] pixels [7:0];
    logic valid_pixels;
    // Holds all values to 0 on reset combinationally.
    always_comb begin
        if (rst_in) begin
            addr_out = 16'h0;
            addr_valid_out = 1'b0;
            valid_pixels_out = 1'b0;
            for (int i = 0; i < 8; i++) begin
                pixels_out[i] = 2'h0;
            end
        end else begin
            addr_out = addr;
            addr_valid_out = addr_valid;
            valid_pixels_out = valid_pixels;
            for (int i = 0; i < 8; i++) begin
                pixels_out[i] = pixels[i];
            end
        end
    end

    // The state evolution of the fetcher.
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= FetchTileNum;
            stall <= 1'b0;
            addr <= 16'h0;
            addr_valid <= 1'b0;
            valid_pixels <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                pixels[i] <= 2'h0;
            end
        end else if (tclk_in) begin
            if (stall) begin
                case (state)
                    FetchTileNum: begin
                        state <= FetchTileDataLow;
                    end
                    FetchTileDataLow: begin
                        state <= FetchTileDataHigh;
                    end
                    FetchTileDataHigh: begin
                        state <= bg_fifo_empty_in ? FetchTileNum : Push2FIFO;
                    end
                    Push2FIFO: begin
                        state <= FetchTileNum;
                    end
                endcase
            end else begin
                if (state == Push2FIFO && bg_fifo_empty_in) begin
                    state <= FetchTileNum;
                end
            end
            stall <= ~stall;
        end
    end

    // Tracks the X position of the fetcher within the tile.
    logic [$clog2(31)-1:0] fetcher_x;
    EvtCounter #(
        .MAX_COUNT(32)
    ) tile_x_counter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(tclk_in && valid_pixels_out),
        .count_out(fetcher_x)
    );

    // Combinational logic determining if we are inside of a window.
    logic inside_window;
    assign inside_window = (X_in + 7) >= WX_in && window_ena_in && WY_cond_in;
    // Tracks the window tile X position.
    logic [$clog2(31)-1:0] window_tile_x;
    EvtCounter #(
        .MAX_COUNT(32)
    ) window_x_counter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(tclk_in && valid_pixels_out && inside_window),
        .count_out(window_tile_x)
    );
    // Tracks the window Y position.
    logic [$clog2(255) - 1:0] window_y;
    assign window_y = (WY_in - Y_in) & 8'hFF;
    // Invalid data entries are interpreted as 0xFF.
    logic [7:0] data;
    assign data = data_valid_in ? data_in : 8'hFF;

    // Determines the base tile address to fetch from.
    logic [15:0] base_addr;
    always_comb begin
        // Determines the base address to fetch from.
        if (background_map_in && !inside_window) begin
            base_addr = 16'h9C00;
        end else if (window_map_in && inside_window) begin
            base_addr = 16'h9C00;
        end else begin
            base_addr = 16'h9800;
        end
    end
    // Determines the offset from the base address to fetch the tile number from.
    logic [4:0] x_coord;
    logic [7:0] y_coord;
    logic [9:0] tile_offset;
    always_comb begin
        x_coord = inside_window ? window_tile_x : ((SCX_in >> 3) + fetcher_x) & 5'h1F;
        y_coord = inside_window ? window_y : ((SCY_in + Y_in) & 8'hFF);
        tile_offset = 10'(x_coord) + (10'(y_coord >> 3) << 5);
    end
    // Fetches the tile number to request.
    logic [7:0] tile_num;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            tile_num <= 8'h0;
        end else begin
            if (tclk_in && state == FetchTileNum) begin
                // First cycle make address request.
                if (!stall) begin
                    // Address request for the tile number.
                    addr <= base_addr + tile_offset;
                    addr_valid <= 1'b1;
                    // Resets pixel_valid_out as it just sent the last row.
                    valid_pixels <= 1'b0;
                // Second cycle save the tile number.
                end else begin
                    tile_num <= data;
                    addr_valid <= 1'b0;
                end
            end
        end
    end

    // Tracks the address base of the tile.
    logic [15:0] tile_base;
    logic [15:0] row_base;
    always_comb begin
        tile_base = addressing_mode_in ? 
            (16'h8000 + (12'(tile_num) << 4)) : 
            (16'h9000 + (12'($signed(tile_num)) << 4));
        row_base = tile_base + (16'(y_coord & 3'h7) << 1);
    end
    // Tracks the low byte of the tile data.
    logic [7:0] tile_data_low;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            tile_data_low <= 8'h0;
        end else begin
            if (tclk_in && state == FetchTileDataLow) begin
                // First cycle make address request.
                if (!stall) begin
                    addr <= row_base;
                    addr_valid <= 1'b1;
                end else begin
                    tile_data_low <= data;
                    addr_valid <= 1'b0;
                end
            end
        end
    end

    // Tracks the high byte of the tile data.
    logic [7:0] tile_data_high;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            tile_data_high <= 8'h0;
        end else begin
            if (tclk_in && state == FetchTileDataHigh) begin
                // First cycle make address request.
                if (!stall) begin
                    addr <= row_base + 16'b1;
                    addr_valid <= 1'b1;
                end else begin
                    tile_data_high <= data;
                    // Mixes the low and high bytes to form the pixel output.
                    valid_pixels <= bg_fifo_empty_in;
                    for (int i = 0; i < 8; i++) begin
                        pixels[i] <= {
                            data[7-i], tile_data_low[7-i]
                        };
                    end
                    addr_valid <= 1'b0;
                end
            end
        end
    end

    // Push2FIFO state logic.
    always_ff @(posedge clk_in) begin
        if (tclk_in && state == Push2FIFO) begin
            // Mixes the low and high bytes to form the pixel output.
            valid_pixels <= bg_fifo_empty_in;
            for (int i = 0; i < 8; i++) begin
                pixels[i] <= {tile_data_high[7-i], tile_data_low[7-i]};
            end
        end
    end
endmodule

`default_nettype wire