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
    // Wire to tell the fetcher has completed a pixel push to LCD.
    output logic advance_X_out    
);
    // Defines the 4 states that takes 2 T-cycles each.
    typedef enum logic[1:0] {
        FetchTileNum = 0, 
        FetchTimeDataLow = 1, 
        FetchTileDataHigh = 2, 
        Push2FIFO = 3
    } FetcherState;
    FetcherState state;
    // Determines whether or not we are waiting a T-cycle to advance the state.
    logic stall;
    // Counts the number of elapsed T-cycles.
    evt_counter #(
        .MAX_COUNT(2)
    ) evt_counter (
        .clk_in(tclk_in),
        .rst_in(rst_in),
        .evt_in(tclk_in),
        .count_out(stall)
    );

    // The state evolution of the fetcher.
    always_ff @(posedge tclk_in && stall) begin
        if (rst_in) begin
            state <= FetchTileNum;
        end else begin
            case (state)
                FetchTileNum: begin
                    if (X_in == $clog2(X_MAX)'(X_MAX-1)) begin
                        state <= FetchTimeDataLow;
                    end
                end
                FetchTimeDataLow: begin
                    state <= FetchTileDataHigh;
                end
                FetchTileDataHigh: begin
                    state <= Push2FIFO;
                end
                Push2FIFO: begin
                    state <= FetchTileNum;
                end
            endcase
        end
    end

    // Tracks the X position of the fetcher within the tile.
    logic [$clog2(31)-1:0] fetcher_x;
    logic x_progress;
    evt_counter #(
        .MAX_COUNT(32)
    ) tile_x_counter (
        .clk_in(tclk_in),
        .rst_in(rst_in),
        .evt_in(x_progress),
        .count_out(fetcher_x)
    );
    // Tracks the Y position of the fetcher within the tile.
    logic [$clog2(255)-1:0] fetcher_y;
    logic y_progress;
    evt_counter #(
        .MAX_COUNT(256)
    ) tile_y_counter (
        .clk_in(tclk_in),
        .rst_in(rst_in),
        .evt_in(y_progress),
        .count_out(fetcher_y)
    );

    // Combinational logic determining if we are inside of a window.
    logic inside_window;
    assign inside_window = (X_in + 7) >= WX_in && window_ena_in && WY_cond_in;
    // Tracks the window tile X position.
    logic [$clog2(31)-1:0] window_tile_x;
    evt_counter #(
        .MAX_COUNT(32)
    ) window_x_counter (
        .clk_in(tclk_in),
        .rst_in(rst_in),
        .evt_in(x_progress && inside_window),
        .count_out(window_tile_x)
    );
    // Tracks the window Y position.
    logic [$clog2(255) - 1:0] window_y;
    assign window_y = (WY_in - Y_in) & 8'hFF;

    // Determines the base tile address to fetch from.
    logic [15:0] base_addr;
    // Fetches the tile number to request.
    logic [9:0] tile_num;
    always_ff @(posedge tclk_in) begin
        if (rst_in) begin
            base_addr <= 16'h9800;
            tile_num <= 10'h0;
        end else begin
            // Uses the first T-cycle to determine the tile map base address.
            if (state == FetchTileNum) begin
                if (!stall) begin
                    if (background_map_in && !inside_window) begin
                        base_addr <= 16'h9C00;
                    end else if (window_map_in && inside_window) begin
                        base_addr <= 16'h9C00;
                    end else begin
                        base_addr <= 16'h9800;
                    end
                // Uses the second T-cycle to determine the tile number.
                end else begin
                    tile_num <= (
                        10'(inside_window ? window_tile_x : ((SCX_in >> 3) + fetcher_x) & 10'h1F) +
                        (((10'(inside_window ? window_y : (Y_in + SCY_in) & 10'hFF)) >> 8) << 5)
                    );
                end
            end
        end
    end

    // Determines the address to request from memory.
    always_ff @(posedge tclk_in) begin
        if (rst_in) begin
            addr_out <= 16'h0;
        end else begin
            if (state == FetchTileNum) begin
            end
        end
    end

    // Push2FIFO state logic.
    always_ff @(posedge tclk_in) begin
        if (rst_in) begin
            advance_X_out <= 1'b0;
        end else begin
            if (state == Push2FIFO && !stall) begin
                advance_X_out <= 1'b1;
            end else begin
                advance_X_out <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire