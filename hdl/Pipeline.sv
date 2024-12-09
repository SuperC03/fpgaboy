`default_nettype none

module Pipeline #(
  parameter WIDTH = 16,
  parameter STAGES = 1
) (
  input wire clk_in, //system clock
  input wire rst_in, //system reset

  input wire [WIDTH-1:0] data_in,  //incoming data
  output wire [WIDTH-1:0] data_out //outgoing data
);
  logic [WIDTH-1:0] pipe [STAGES-1:0];

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        for (int i = 0; i < STAGES; i++) begin
            pipe[i] <= WIDTH'(1'b0);
        end
    end else begin
      pipe[0] <= data_in;
      for (int i = 1; i < STAGES; i++) begin
        pipe[i] <= pipe[i-1];
      end
    end
  end

  assign data_out = pipe[STAGES-1];
endmodule

`default_nettype wire