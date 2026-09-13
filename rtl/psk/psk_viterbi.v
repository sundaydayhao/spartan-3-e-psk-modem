`timescale 1ns/1ps
`default_nettype none
// Streaming hard-decision Viterbi, K=5, rate 1/2, polynomials 0x17/0x19.
// 16 states with 48-bit survivor histories; one ACS state per clock.
module psk_viterbi(input wire clk,reset,input wire [1:0] symbol,
    input wire valid,output reg bit_out,output reg bit_valid);
    reg [7:0] metric[0:15], next_metric[0:15];
    reg [47:0] path[0:15], next_path[0:15];
    reg [1:0] received;
    reg [1:0] state;
    reg [3:0] idx,best_state;
    reg [7:0] best_metric;
    reg [5:0] count;
    wire [3:0] pred_a={1'b0,idx[3:1]}, pred_b={1'b1,idx[3:1]};
    wire [1:0] code={(^(idx & 4'h9)),(^(idx & 4'h7))};
    wire [1:0] ea=code^received, eb=(code^2'b11)^received;
    wire [7:0] ma=metric[pred_a]+{7'd0,ea[0]}+{7'd0,ea[1]};
    wire [7:0] mb=metric[pred_b]+{7'd0,eb[0]}+{7'd0,eb[1]};
    wire [7:0] chosen=ma<=mb ? ma:mb;
    wire [3:0] predecessor=ma<=mb ? pred_a:pred_b;
    integer n;
    always @(posedge clk) begin
        bit_valid<=0;
        if(reset) begin
            state<=0;count<=0;bit_out<=0;idx<=0;best_metric<=255;best_state<=0;
            for(n=0;n<16;n=n+1) begin metric[n]<=0;path[n]<=0;end
        end else case(state)
            0: if(valid) begin received<=symbol;idx<=0;best_metric<=255;state<=1;end
            1: begin
                next_metric[idx]<=chosen;
                next_path[idx]<={path[predecessor][46:0],idx[0]};
                if(chosen<best_metric) begin best_metric<=chosen;best_state<=idx;end
                if(idx==15) begin idx<=0;state<=2;end
                else idx<=idx+1'b1;
            end
            2: begin
                metric[idx]<=next_metric[idx]-best_metric;path[idx]<=next_path[idx];
                if(idx==15) begin
                    if(count<47) count<=count+1'b1;
                    else begin bit_out<=next_path[best_state][47];bit_valid<=1;end
                    state<=0;
                end else idx<=idx+1'b1;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
