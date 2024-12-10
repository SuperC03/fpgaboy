`default_nettype none


module XMatcher (
    input wire sprite_ena_in,
    input wire [$clog2(160)-1:0] X_in,
    input wire [17:0] sprite_buf_in,

    output logic sprite_hit_out,
    output logic [5:0] sprite_num_out,
    output logic [3:0] sprite_row_out
);
    logic [7:0] sprite_X;
    assign sprite_X = sprite_buf_in[17:10];
    assign sprite_num_out = sprite_buf_in[9:4];
    assign sprite_row_out = sprite_buf_in[3:0];

    always_comb begin
        if (
            sprite_ena_in && 
            sprite_X != 8'h0 && sprite_X <= (X_in + 8'h8)
        ) begin
            sprite_hit_out = 1'b1;
        end else begin
            sprite_hit_out = 1'b0;
        end
    end
endmodule


module SpriteFetcher #(
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

    // Whether sprite mode is enabled.
    input wire sprite_ena_in,
    // Access to the sprite registers.
    input wire [17:0] sprite_buffer_in [9:0],
    // Whether we've detected a sprite.
    output logic sprite_detected_out,

    // Wire requesting a tile row from memory.
    output logic [15:0] addr_out,
    // Valid request to fetch data from memory.
    output logic addr_valid_out,
    // Data fetched from memory.
    input wire [7:0] data_in,
    // Whether the data fetched is valid.
    input wire data_valid_in,

    // Whether the Sprite FIFO is empty.
    input wire sprite_fifo_empty_in,
    // Pixels to push to the Background FIFO.
    output logic valid_pixels_out,
    output logic [1:0] pixels_out [7:0]
);
        // Defines the 4 states that takes 2 T-cycles each.
    typedef enum logic[2:0] {
        FetchTileNum = 0, 
        FetchTileDataLow = 1, 
        FetchTileDataHigh = 2, 
        Push2FIFO = 3,
        Pause = 4
    } FetcherState;
    FetcherState state;
    // Determines whether or not we are waiting a T-cycle to advance the state.
    logic stall;

    // Internal buffers for the fetcher for output values to hold.
    logic [15:0] addr;
    logic addr_valid;
    logic [1:0] pixels [7:0];
    logic valid_pixels;
    logic sprite_detected;
    // Holds all values to 0 on reset combinationally.
    always_comb begin
        if (rst_in) begin
            sprite_detected_out = 1'b0;
            addr_out = 16'h0;
            addr_valid_out = 1'b0;
            valid_pixels_out = 1'b0;
            for (int i = 0; i < 8; i++) begin
                pixels_out[i] = 2'h0;
            end
        end else begin
            sprite_detected_out = sprite_detected | (state != Pause);
            addr_out = addr;
            addr_valid_out = addr_valid;
            valid_pixels_out = valid_pixels;
            for (int i = 0; i < 8; i++) begin
                pixels_out[i] = pixels[i];
            end
        end
    end

    // Decides whether any sprites are up. 
    logic [9:0] sprite_hit;
    logic [5:0] sprite_numbers [9:0];
    logic [3:0] sprite_rows [9:0];
    genvar sprite_buf_pos;
    generate
        for (sprite_buf_pos = 0; sprite_buf_pos < 10; sprite_buf_pos++) begin
            XMatcher matcher (
                .sprite_ena_in(sprite_ena_in),
                .X_in(X_in),
                .sprite_buf_in(sprite_buffer_in[sprite_buf_pos]),

                .sprite_hit_out(sprite_hit[sprite_buf_pos]),
                .sprite_num_out(sprite_numbers[sprite_buf_pos]),
                .sprite_row_out(sprite_rows[sprite_buf_pos])
            );
        end
    endgenerate

    // Notes what sprite to render if we have a hit.
    logic [3:0] sprite_found;
    always_comb begin
        sprite_found = 4'h0;       // Default value
        sprite_detected = 1'b0;    // Default state
        for (int i = 0; i < 10; i++) begin
            if (sprite_hit[i] && !sprite_detected) begin
                sprite_found = 4'(i);
                sprite_detected = 1'b1;
            end
        end
    end 
    // Stores the sprite position for the fetcher.
    logic [3:0] sprite_pos;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            sprite_pos <= 4'h0;
        end else begin
            if (tclk_in) begin
                sprite_pos <= sprite_found;
            end
        end
    end

    // The state evolution of the fetcher.
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= Pause;
            stall <= 1'b0;
            addr <= 16'h0;
            addr_valid <= 1'b0;
            valid_pixels <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                pixels[i] <= 2'h0;
            end
        end else if (tclk_in) begin
            if (state == Pause && sprite_detected) begin
                state <= FetchTileNum;
                stall <= 1'b0;
            end else if (state == Pause && !sprite_detected) begin
                state <= Pause;
                stall <= 1'b0;
            end else if (state == Push2FIFO && sprite_fifo_empty_in) begin
                state <= FetchTileNum;
                stall <= 1'b0;
            end else begin
                if (stall) begin
                    case (state)
                        FetchTileNum: begin
                            state <= FetchTileDataLow;
                        end
                        FetchTileDataLow: begin
                            state <= FetchTileDataHigh;
                        end
                        FetchTileDataHigh: begin
                            state <= sprite_fifo_empty_in ? FetchTileNum : Push2FIFO;
                        end
                    endcase
                end
                stall <= ~stall;
            end
        end
    end

    // Invalid data entries are interpreted as 0xFF.
    logic [7:0] data;
    assign data = data_valid_in ? data_in : 8'hFF;

    // Fetches the tile number to request.
    logic [7:0] tile_num;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            tile_num <= 8'h0;
        end else begin
            if (tclk_in && state == FetchTileNum) begin
                // First cycle make address request.
                if (!stall) begin
                    addr_out <= 16'hFE00 + (16'(sprite_numbers[sprite_pos]) << 4);
                    addr_valid_out <= 1'b1;
                end else begin
                    tile_num <= data;
                end
            end
        end
    end

    // Tracks the address base of the tile.
    logic [15:0] tile_base;
    logic [15:0] row_base;
    /** @note
    * Vertical flipping of bg is a CGB only feature:
    * https://gbdev.io/pandocs/pixel_fifo.html
    */
    always_comb begin
        tile_base = (16'h8000 + (12'(tile_num) << 4));
        row_base = tile_base + (16'(sprite_rows[sprite_pos]) << 1);
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
                    valid_pixels <= sprite_fifo_empty_in;
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
            valid_pixels <= sprite_fifo_empty_in;
            for (int i = 0; i < 8; i++) begin
                pixels[i] <= {tile_data_high[7-i], tile_data_low[7-i]};
            end
        end
    end
endmodule

`default_nettype wire