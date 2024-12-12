`timescale 1ps/1ps
`default_nettype none

module fpgaboy(
    // Clock signal.s
    input wire          clk_100mhz, //100 MHz onboard clock
    // Switches
    input wire [15:0]   sw,         //all 16 input slide switches
    input wire [3:0]    btn,        //all four momentary button switches
    // LED outputs.
    output wire [15:0]  led,        //16 green output LEDs (located right above switches)
    output wire [2:0]   rgb0,       //RGB channels of RGB LED0
    output wire [2:0]   rgb1,       //RGB channels of RGB LED1
    // Seven segment display.
    output logic [3:0] ss0_an,      //anode control for upper four digits of seven-seg display
    output logic [3:0] ss1_an,      //anode control for lower four digits of seven-seg display
    output logic [6:0] ss0_c,       //cathode controls for the segments of upper four digits
    output logic [6:0] ss1_c        //cathode controls for the segments of lower four digits
    // hdmi port
    // output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    // output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    // output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);
    // Reset logic.
    logic rst;
    assign rst = sw[0] && btn[0];

    // State machine to duty cycle the top-level modules.
    typedef enum logic [1:0] {
        CPU,
        PPU,
        MEM,
        SETTLE
    } module_active;
    module_active state;
    // Counter to track how far along one t-cycle we are.
    logic [$clog2(1_000)-1:0] t_cycle;
    EvtCounter #(
        .MAX_COUNT(1_000)
    ) tclk_tick (
        .clk_in(clk_100mhz),
        .rst_in(rst),
        .evt_in(1'b1),
        .count_out(t_cycle)
    );
    // always_ff @(posedge clk_100mhz) begin
    //     case (t_cycle)
    //         5'd0: state <= CPU;
    //         5'd8: state <= PPU;
    //         5'd16: state <= MEM;
    //         5'd24: state <= SETTLE;
    //     endcase
    // end
    // // Individual tclk drivers.
    logic ppu_tclk;
    // assign ppu_tclk = state == PPU && ((t_cycle & 3'h7) == 3'h0);
    assign ppu_tclk = 1'b1;

    /***************************************************************************
    * @note CPU signals.
    ***************************************************************************/


    /***************************************************************************
    * @note PPU signals.
    ***************************************************************************/
    // PPU control registers.
    logic [7:0] LCDC;
    logic [7:0] STAT;
    // PPU mode.
    logic [1:0] ppu_mode;
    // Screen position.
    logic [7:0] SCY;
    logic [7:0] SCX;
    // Window position.
    logic [7:0] WY;
    logic [7:0] WX;
    // Rendering scanline position.
    logic [7:0] LY;
    // Scanline interrupt position.
    logic [7:0] LYC;
    // Palettes
    logic [7:0] BGP;
    logic [7:0] OBP0;
    logic [7:0] OBP1;
    // Pixel to push.
    logic [1:0] pixel;
    logic pixel_valid;
    // Display control signals.
    logic hblank;
    logic vblank;
    // PPU memory requests.
    logic [15:0] ppu_addr;
    logic ppu_addr_valid;
    // OAM memory requests.
    logic [15:0] oam_addr;
    logic oam_addr_valid;
    /***************************************************************************
    * @note Memory signals.
    ***************************************************************************/
    // Memory data.
    logic [7:0] mem_data;
    logic mem_data_valid;
    // OAM data.
    logic [7:0] oam_data;
    logic oam_data_valid;

    PixelProcessingUnit ppu(
        // Standard clock and reset signals.
        .clk_in(clk_100mhz),
        .rst_in(rst),

        // The T-cycle and M-cycle clocks.
        .tclk_in(ppu_tclk),
        
        // The LCDC and STAT registers | $FF40 and $FF41.
        .LCDC_in(LCDC),
        // .STAT_in(STAT),
        // The SCY and SCX registers | $FF42 and $FF43.
        .SCY_in(SCY),
        .SCX_in(SCX),
        // Exposing the LY register | $FF44.
        .LY_out(LY),
        // LYC register | $FF45.
        .LYC_in(LYC),
        // The BGP, OBP0, and OBP1 registers | $FF47, $FF48, and $FF49.
        .BGP_in(BGP),
        .OBP0_in(OBP0),
        .OBP1_in(OBP1),
        // The WY and WX registers | $FF4A and $FF4B.
        .WY_in(WY),
        .WX_in(WX),

        // The data requested from memory.
        .addr_out(ppu_addr),
        .addr_valid_out(ppu_addr_valid),
        .data_in(mem_data),
        .data_valid_in(mem_data_valid && state == PPU),
        // OAM signals.
        .oam_addr_out(oam_addr),
        .oam_addr_valid_out(oam_addr_valid),
        .oam_data_in(oam_data),
        .oam_data_valid_in(oam_data_valid),

        // The data to be output to the LCD.
        .pixel_out(pixel),
        .pixel_valid_out(pixel_valid),
        // The mode of the PPU.
        .mode_out(STAT[1:0]),
        // The LY = LYC signal.
        .ly_eq_lyc_out(STAT[2]),

        // Whether or not we're HBlank.
        .hblank_out(hblank),
        // Whether or not we're VBlank.
        .vblank_out(vblank)
    );

    // Writes out switches to the LEDs for debugging.
    assign led = sw;
    // Turns off the annoying rgb leds.
    assign rgb0 = 3'b000;
    assign rgb1 = 3'b000;

    // Writes out the requested address to the seven segment display.
    logic [6:0] ss_c;
    seven_segment_controller mssc(
        .clk_in(clk_100mhz),
        .rst_in(rst),
        // .val_in({LCDC, STAT, ppu_addr[15:0]}),
        .val_in({8'h0, LYC, LCDC, STAT}),
        .cat_out(ss_c),
        .an_out({ss0_an, ss1_an})
    );
    assign ss0_c = ss_c[6:0];
    assign ss1_c = ss_c[6:0];

    // Assigns some default values to just get something on screen.
    assign LCDC = sw[7:0];
    assign LYC = sw[15:8];
    assign STAT[7:3] = 5'b00000;
    always_comb begin
        mem_data = 8'hB3;
        mem_data_valid = 1'b1;
        oam_data = 8'hB3;
        oam_data_valid = 1'b0;
        BGP = 8'b11_10_01_00;
        OBP0 = 8'b11_10_01_00;
        OBP1 = 8'b11_10_01_00;
        SCY = 8'h00;
        SCX = 8'h00;
        WY = 8'h00;
        WX = 8'h00;
    end

endmodule