`default_nettype none


module FIFO #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    // clock and reset
    input wire clk_in,
    input wire rst_in,

    // FIFO control signals
    input wire wr_en,
    input wire [WIDTH-1:0] data_in,
    input wire rd_en,

    // FIFO data signals
    output logic [WIDTH-1:0] data_out,
    output logic data_valid_out,
    output logic [$clog2(DEPTH):0] occupancy_out
);
    // The FIFO memory.
    logic [WIDTH-1:0] mem [DEPTH-1:0];
    // The read and write pointers.
    logic [$clog2(DEPTH)-1:0] rd_ptr;
    logic [$clog2(DEPTH)-1:0] wr_ptr;
    // Current occupancy of the FIFO.
    logic [$clog2(DEPTH):0] occupancy;

    // Combinational logic to determine if we are reading and writing this cycle.
    logic read;
    logic write;
    always_comb begin
        write = wr_en && (occupancy < ($clog2(DEPTH)+1)'(DEPTH));
        read = rd_en && (occupancy > ($clog2(DEPTH)+1)'(0));
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            rd_ptr <= $clog2(DEPTH)'(0);
            wr_ptr <= $clog2(DEPTH)'(0);
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= WIDTH'(0);
            end
            occupancy <= ($clog2(DEPTH)+1)'(0);
            data_out <= WIDTH'(0);
            data_valid_out <= 1'b0;
        end else begin
            if (write) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr >= $clog2(DEPTH)'(DEPTH -  1)) ? 
                        $clog2(DEPTH)'(0) : wr_ptr + $clog2(DEPTH)'(1);
            end
            
            if (read) begin
                data_out <= mem[rd_ptr];
                data_valid_out <= 1'b1;
                rd_ptr <= (rd_ptr >= $clog2(DEPTH)'(DEPTH -  1)) ? 
                        $clog2(DEPTH)'(0) : rd_ptr + $clog2(DEPTH)'(1);
            end else begin
                data_valid_out <= 1'b0;
            end

            // Handles the simultaneous read-write case on occupancies.
            if (write && !read) begin
                occupancy <= occupancy + ($clog2(DEPTH)+1)'(1);
            end else if (!write && read) begin
                occupancy <= occupancy - ($clog2(DEPTH)+1)'(1);
            end
        end
    end

    assign occupancy_out = occupancy;
endmodule

`default_nettype wire