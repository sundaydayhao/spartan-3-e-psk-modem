`timescale 1ns/1ps
`default_nettype none
module psk_varicode(input wire clk,reset,bit_in,valid,
    output reg [7:0] character,output reg character_valid);
    reg [11:0] code;
    reg previous_zero,overflow;
    wire [7:0] decoded=varicode(code[11:1]);
    `include "varicode.vh"
    always @(posedge clk) begin
        character_valid<=0;
        if(reset) begin code<=0;previous_zero<=1;overflow<=0;character<=0;end
        else if(valid) begin
            previous_zero<=!bit_in;
            if(!bit_in && previous_zero) begin
                if(decoded!=0 && !overflow) begin character<=decoded;character_valid<=1;end
                code<=0;overflow<=0;
            end else begin code<={code[10:0],bit_in};overflow<=overflow|code[11];end
        end
    end
endmodule
`default_nettype wire
