`timescale 1ns/1ps
`default_nettype none
// Symbol FIFO, bit alignment, depuncturing, differential interleaver delay,
// convolutional decoding and character framing. Only text framing is exposed.
module psk_decode(input wire clk,reset,input wire [4:0] mode,
    input wire [2:0] symbol,input wire valid,output wire room,
    output wire [7:0] character,output wire character_valid);
    `include "mode_config.vh"
    wire [1:0] family=mode_family(mode);
    wire [4:0] k=mode_k(mode);
    wire fec=(k!=0 && family!=1);
    wire punctured=mode_puncture(mode);
    wire [9:0] depth=mode_depth(mode);
    reg [2:0] fifo[0:15];
    reg [4:0] wp,rp;
    wire [4:0] used=wp-rp;
    assign room=(used<4);
    reg overflow;
    reg [3:0] state,resume;
    reg [2:0] bits;
    reg [1:0] remaining;
    reg previous,have_previous,alignment;
    reg branch_hold;
    reg [1:0] pair_hold,known_hold;
    (* ram_style="block" *) reg [1:0] deinterleave[0:2047];
    reg [1:0] delayed;
    reg [9:0] ptr0,ptr1,fill0,fill1;
    wire [9:0] pointer=branch_hold ? ptr1:ptr0;
    wire [9:0] filled=branch_hold ? fill1:fill0;
    always @(posedge clk) if(state==2 && depth!=0) begin
        delayed<=deinterleave[{branch_hold,pointer}];
        deinterleave[{branch_hold,pointer}]<={known_hold[1],pair_hold[1]};
    end
    reg [1:0] fec_pair,fec_known;
    reg fec_valid;
    wire fec_ready,fec_bit,fec_bit_valid,fec_branch;
    wire [7:0] fec_cost;
    psk_fec_beam beam(.clk(clk),.reset(reset),.k(k),
        .poly0(mode_p0(mode)),.poly1(mode_p1(mode)),.branch(branch_hold),
        .pair(fec_pair),.known(fec_known),.valid(fec_valid),.ready(fec_ready),
        .bit_out(fec_bit),.bit_valid(fec_bit_valid),.branch_out(fec_branch),.cost(fec_cost));
    reg raw_bit,raw_valid,q_valid;
    reg [1:0] q_symbol;
    wire q_bit,q_bit_valid;
    psk_viterbi qdecoder(.clk(clk),.reset(reset),.symbol(q_symbol),.valid(q_valid),
        .bit_out(q_bit),.bit_valid(q_bit_valid));
    wire [7:0] psk_char,mfsk0,mfsk1;
    wire psk_valid,mfsk0_valid,mfsk1_valid;
    psk_varicode psk_chars(.clk(clk),.reset(reset),
        .bit_in(family==1 ? q_bit:raw_bit),
        .valid(family==1 ? q_bit_valid:(raw_valid && family==0 && !fec)),
        .character(psk_char),.character_valid(psk_valid));
    mfsk_bit_decoder mf0(.clk(clk),.reset(reset),
        .bit_in(fec ? fec_bit:raw_bit),
        .valid(fec ? (fec_bit_valid && !fec_branch):(raw_valid && family==2)),
        .character(mfsk0),.character_valid(mfsk0_valid));
    mfsk_bit_decoder mf1(.clk(clk),.reset(reset),.bit_in(fec_bit),
        .valid(fec_bit_valid && fec_branch),
        .character(mfsk1),.character_valid(mfsk1_valid));
    // Scores have fractional bits so a clean branch decays all the way to 0.
    reg [15:0] score0,score1;
    reg [1:0] scored,selected;
    reg candidate_branch;
    reg [5:0] votes;
    wire candidate0=score0+16'd64<score1;
    wire candidate1=score1+16'd64<score0;
    wire use_mfsk=mode_mfsk(mode);
    assign character=use_mfsk ? ((fec && selected==1 && !punctured) ? mfsk1:mfsk0):psk_char;
    assign character_valid=use_mfsk ?
        (!fec ? mfsk0_valid:punctured ? mfsk0_valid:
            selected==0 ? mfsk0_valid:selected==1 ? mfsk1_valid:1'b0):psk_valid;
    always @(posedge clk) begin
        raw_valid<=0;q_valid<=0;fec_valid<=0;
        if(reset) begin
            wp<=0;rp<=0;state<=0;bits<=0;remaining<=0;overflow<=0;
            previous<=0;have_previous<=0;alignment<=0;branch_hold<=0;
            ptr0<=0;ptr1<=0;fill0<=0;fill1<=0;raw_bit<=0;q_symbol<=0;
            score0<=0;score1<=0;scored<=0;selected<=2;votes<=0;candidate_branch<=0;
        end else begin
            if(valid) begin
                if(used==16) overflow<=1;
                else begin fifo[wp[3:0]]<=symbol;wp<=wp+1'b1;end
            end
            if(fec_bit_valid) begin
                if(fec_branch) begin
                    score1<=score1-(score1>>6)+{4'd0,fec_cost,4'd0};scored[1]<=1;
                end else begin
                    score0<=score0-(score0>>6)+{4'd0,fec_cost,4'd0};scored[0]<=1;
                end
                if(scored==3 && (candidate0 || candidate1)) begin
                    if(candidate_branch!=candidate1) begin candidate_branch<=candidate1;votes<=0;end
                    else if(votes<63) votes<=votes+1'b1;
                    else selected<={1'b0,candidate_branch};
                end else votes<=0;
            end
            case(state)
                0:if(wp!=rp) begin
                    bits<=fifo[rp[3:0]];rp<=rp+1'b1;
                    remaining<=family==2 ? 3:1;
                    if(family==1) begin q_symbol<=fifo[rp[3:0]][1:0];q_valid<=1;end
                    else state<=1;
                end
                1:begin
                    if(!fec) begin
                        raw_bit<=bits[0];raw_valid<=1;bits<=bits>>1;remaining<=remaining-1'b1;
                        if(remaining==1) state<=0;
                    end else if(punctured) begin
                        pair_hold<=bits[1:0];known_hold<=3;branch_hold<=0;
                        resume<=11;state<=2;
                    end else begin
                        previous<=bits[0];have_previous<=1;
                        bits<=bits>>1;remaining<=remaining-1'b1;
                        if(have_previous) begin
                            pair_hold<={bits[0],previous};known_hold<=3;
                            branch_hold<=alignment;alignment<=!alignment;
                            resume<=remaining==1 ? 0:1;state<=2;
                        end else if(remaining==1) state<=0;
                    end
                end
                2:begin
                    if(depth==0) begin fec_pair<=pair_hold;fec_known<=known_hold;state<=6;end
                    else begin
                        state<=3;
                    end
                end
                3:begin
                    fec_pair<={delayed[0],pair_hold[0]};
                    fec_known<={delayed[1],known_hold[0]};
                    if(branch_hold) begin
                        ptr1<=pointer==depth-1 ? 0:pointer+1'b1;
                        if(fill1<depth) fill1<=fill1+1'b1;
                    end else begin
                        ptr0<=pointer==depth-1 ? 0:pointer+1'b1;
                        if(fill0<depth) fill0<=fill0+1'b1;
                    end
                    state<=filled>=depth ? 6:resume;
                end
                6:if(fec_ready) begin fec_valid<=1;state<=7;end
                7:state<=resume;
                11:begin
                    pair_hold<={1'b0,bits[2]};known_hold<=1;branch_hold<=0;
                    resume<=0;state<=2;
                end
                default:state<=0;
            endcase
        end
    end
endmodule
`default_nettype wire
