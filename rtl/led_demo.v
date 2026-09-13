`timescale 1ns / 1ps
`default_nettype none

// Xilinx/Digilent Spartan-3E Starter Kit: active-high onboard LEDs.
// LED0 stays on; LED7 toggles every 0.5 seconds from the 50 MHz clock.
module led_demo (
    input  wire       clk_50mhz,
    output wire [7:0] led,
    output wire [3:0] lcd_data,
    output wire       lcd_e,
    output wire       lcd_rs,
    output wire       lcd_rw,
    output wire       sf_ce0,
    output wire       sf_oe,
    output wire       sf_we
);
    reg [24:0] count = 25'd0;
    reg heartbeat = 1'b0;

    always @(posedge clk_50mhz) begin
        if (count == 25'd24_999_999) begin
            count <= 25'd0;
            heartbeat <= ~heartbeat;
        end else begin
            count <= count + 1'b1;
        end
    end

    wire lcd_ready;
    lcd_text display (
        .clk_50mhz(clk_50mhz), .data(lcd_data), .enable(lcd_e),
        .rs(lcd_rs), .rw(lcd_rw), .ready(lcd_ready)
    );

    // LCD data pins also connect to StrataFlash. Keep its bus inactive.
    assign sf_ce0 = 1'b1;
    assign sf_oe = 1'b1;
    assign sf_we = 1'b1;
    assign led = {heartbeat, 5'b00000, lcd_ready, 1'b1};
endmodule

`default_nettype wire
