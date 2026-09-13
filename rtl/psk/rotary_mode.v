`timescale 1ns/1ps
`default_nettype none
// UG230: detent A=B=0; clockwise cycle 00 -> 10 -> 11 -> 01 -> 00.
// Filter contact chatter, reject diagonal transitions, and count full detents.
module rotary_mode #(
    parameter ROT_FILTER_CYCLES=12500, // 250 us at 50 MHz
    parameter BUTTON_FILTER_CYCLES=1000000 // 20 ms
)(input wire clk,rot_a,rot_b,rot_center,
    output reg [4:0] active_mode=0,pending_mode=0,
    output reg editing=0,applied=0);
    `include "mode_config.vh"
    (* ASYNC_REG="TRUE" *) reg [1:0] rot_meta=0,rot_sync=0;
    (* ASYNC_REG="TRUE" *) reg btn_meta=0,btn_sync=0;
    reg [1:0] candidate=0,stable=0,previous=0;
    reg [19:0] rot_count=0,btn_count=0;
    reg btn_stable=0,pressed=0;
    reg signed [3:0] quarters=0;
    reg signed [3:0] delta;
    wire signed [4:0] total=quarters+delta;
    reg step=0,clockwise=0;
    always @* begin
        case({previous,stable})
            4'b0010,4'b1011,4'b1101,4'b0100:delta=1;
            4'b0001,4'b0111,4'b1110,4'b1000:delta=-1;
            default:delta=0;
        endcase
    end
    always @(posedge clk) begin
        rot_meta<={rot_a,rot_b};rot_sync<=rot_meta;
        btn_meta<=rot_center;btn_sync<=btn_meta;
        if(rot_sync!=candidate) begin candidate<=rot_sync;rot_count<=0;end
        else if(rot_count<ROT_FILTER_CYCLES-1) rot_count<=rot_count+1'b1;
        else stable<=candidate;

        pressed<=0;
        if(btn_sync==btn_stable) btn_count<=0;
        else if(btn_count<BUTTON_FILTER_CYCLES-1) btn_count<=btn_count+1'b1;
        else begin
            btn_count<=0;btn_stable<=btn_sync;
            if(btn_sync) pressed<=1;
        end

        step<=0;
        if(previous!=stable) begin
            previous<=stable;
            if(delta==0) quarters<=0; // Missed/illegal two-bit transition.
            else if(stable==0) begin
                quarters<=0;
                if(total==4 || total==-4) begin step<=1;clockwise<=!total[4];end
            end else quarters<=total;
        end

        applied<=0;
        if(pressed) begin
            if(editing) begin
                active_mode<=pending_mode;editing<=0;
                applied<=(pending_mode!=active_mode);
            end
        end else if(step && !btn_sync && !btn_stable) begin
            if(clockwise) pending_mode<=(pending_mode==`PSK_MODE_COUNT-1) ? 5'd0:pending_mode+1'b1;
            else pending_mode<=(pending_mode==0) ? (`PSK_MODE_COUNT-1):pending_mode-1'b1;
            editing<=1;
        end
    end
endmodule
`default_nettype wire
