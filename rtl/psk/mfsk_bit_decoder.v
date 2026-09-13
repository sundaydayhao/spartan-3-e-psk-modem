`timescale 1ns/1ps
`default_nettype none
module mfsk_bit_decoder(input wire clk,reset,bit_in,valid,
    output reg [7:0] character,output reg character_valid);
    reg [11:0] code;
    wire [11:0] next_code={code[10:0],bit_in};
    `include "mfsk_varicode.vh"
    wire [7:0] decoded=mfsk_decode(next_code[11:1]);
    always @(posedge clk) begin
        character_valid<=0;
        if(reset) begin code<=1;character<=0;end
        else if(valid) begin
            if(next_code[2:0]==1) begin
                code<=1;
                if(decoded!=0) begin character<=decoded;character_valid<=1;end
            end else code<=next_code;
        end
    end
endmodule
`default_nettype wire
