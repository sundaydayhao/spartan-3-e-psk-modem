`timescale 1ns / 1ps
`default_nettype none

// UG230 chapter 5: ST7066U/HD44780-compatible LCD, write-only 4-bit bus.
// Each line must contain exactly 16 ASCII characters (pad with spaces).
module lcd_live (
    input wire clk_50mhz, input wire [127:0] line1, line2,
    output reg [3:0] data = 4'h0,
    output reg enable = 1'b0,
    output reg rs = 1'b0,
    output wire rw,
    output reg ready = 1'b0
);
    reg [127:0] LINE1 = "                ", LINE2 = "                ";
    localparam WAIT = 3'd0, SETUP = 3'd1, PULSE = 3'd2,
               HOLD = 3'd3, DONE = 3'd4;
    reg [2:0] state = WAIT;
    reg [5:0] prescaler = 6'd0;
    reg [15:0] delay_us = 16'd40000;
    reg [5:0] item = 6'd0;
    reg low_nibble = 1'b0;

    function [7:0] sequence_byte;
        input [5:0] index;
        begin
            case (index)
                0, 1, 2: sequence_byte = 8'h30; // single bootstrap nibble
                3: sequence_byte = 8'h20;       // switch to 4-bit mode
                4: sequence_byte = 8'h28;       // two lines, 5x8 font
                5: sequence_byte = 8'h06;       // increment address
                6: sequence_byte = 8'h0c;       // display on, cursor off
                7: sequence_byte = 8'h01;       // clear (needs 1.64 ms)
                8: sequence_byte = 8'h80;       // first line, DDRAM 0x00
                25: sequence_byte = 8'hc0;      // second line, DDRAM 0x40
                default: begin
                    if (index >= 9 && index <= 24)
                        sequence_byte = LINE1 >> ((24-index)*8);
                    else if (index >= 26 && index <= 41)
                        sequence_byte = LINE2 >> ((41-index)*8);
                    else
                        sequence_byte = 8'h20;
                end
            endcase
        end
    endfunction

    wire [7:0] current_byte = sequence_byte(item);
    assign rw = 1'b0;

    // Clock enable at 1 MHz, with all logic kept on the 50 MHz clock.
    // Setup, E high and hold each last at least 1 us; normal commands
    // have a further 50 us wait. No asynchronous divided clock is used.
    always @(posedge clk_50mhz) begin
        if (prescaler != 6'd49) begin
            prescaler <= prescaler + 1'b1;
        end else begin
            prescaler <= 6'd0;
            case (state)
                WAIT: begin
                    if (delay_us != 0)
                        delay_us <= delay_us - 1'b1;
                    else if (item == 42) begin
                        ready <= 1'b1;
                        delay_us <= 16'd50000; state <= DONE;
                    end else begin
                        data <= current_byte[7:4];
                        rs <= (item >= 9 && item != 25);
                        low_nibble <= 1'b0;
                        state <= SETUP;
                    end
                end
                SETUP: begin
                    enable <= 1'b1;
                    state <= PULSE;
                end
                PULSE: begin
                    enable <= 1'b0;
                    state <= HOLD;
                end
                HOLD: begin
                    if (item >= 4 && !low_nibble) begin
                        data <= current_byte[3:0];
                        low_nibble <= 1'b1;
                        state <= SETUP;
                    end else begin
                        case (item)
                            0: delay_us <= 16'd5000;
                            1: delay_us <= 16'd200;
                            2, 3: delay_us <= 16'd100;
                            7: delay_us <= 16'd2000;
                            default: delay_us <= 16'd50;
                        endcase
                        item <= item + 1'b1;
                        state <= WAIT;
                    end
                end
                DONE: begin
                    enable <= 1'b0;
                    if (delay_us != 0) delay_us <= delay_us - 1'b1;
                    else begin LINE1 <= line1; LINE2 <= line2; item <= 8; state <= WAIT; end
                end
                default: begin
                    state <= WAIT;
                    item <= 6'd0;
                    delay_us <= 16'd40000;
                    enable <= 1'b0;
                    ready <= 1'b0;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
