`timescale 1ns/1ps
`default_nettype none
// HPM uncoded 8PSK sends three consecutive MFSK Varicode bits, LSB first.
// A new codeword starts with 1; detecting 001 terminates the previous code.
module psk_mfsk_varicode(input wire clk,reset,input wire [2:0] symbol,
    input wire valid,output reg [7:0] character,output reg character_valid);
    reg [2:0] bits;
    reg [1:0] remaining;
    reg [11:0] code;
    wire [11:0] next_code={code[10:0],bits[0]};
    `include "mfsk_varicode.vh"
    wire [7:0] decoded=mfsk_decode(next_code[11:1]);
    always @(posedge clk) begin
        character_valid<=0;
        if(reset) begin bits<=0;remaining<=0;code<=1;character<=0;end
        else if(valid) begin bits<=symbol;remaining<=3;end
        else if(remaining!=0) begin
            bits<={1'b0,bits[2:1]};remaining<=remaining-1'b1;
            if(next_code[2:0]==3'b001) begin
                code<=1;
                if(decoded!=0) begin character<=decoded;character_valid<=1;end
            end else code<=next_code;
        end
    end
endmodule
`default_nettype wire
