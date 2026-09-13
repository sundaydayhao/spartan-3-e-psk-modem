`timescale 1ns/1ps
`default_nettype none
// Registered ROM ports allow XST to map this table to block memory.
module nco_sine(input wire clk,enable,input wire [9:0] phase,
    output reg signed [11:0] cosine,sine);
    (* rom_style="block", ram_style="block" *) reg signed [11:0] sine_rom[0:1023];
    wire [9:0] quadrant=phase+10'd256;
    initial begin
        `include "sine_init.vh"
    end
    always @(posedge clk) if(enable) begin
        cosine<=sine_rom[quadrant];
        sine<=sine_rom[phase];
    end
endmodule
`default_nettype wire
