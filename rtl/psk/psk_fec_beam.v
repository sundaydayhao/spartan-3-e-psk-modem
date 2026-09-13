`timescale 1ns/1ps
`default_nettype none
// 64-survivor, hard-decision M-algorithm convolutional decoder.
// K=7 is a complete 64-state trellis. K=13/16 retain the best 64 distinct
// states, reducing memory at the cost of performance on difficult channels.
// Two independent bit-pair alignments share RAM and ACS hardware.
module psk_fec_beam(input wire clk,reset,input wire [4:0] k,
    input wire [15:0] poly0,poly1,input wire branch,
    input wire [1:0] pair,known,input wire valid,output wire ready,
    output reg bit_out,bit_valid,branch_out,output reg [7:0] cost);
    // [214:207] metric, [206:192] encoder state, [191:0] history.
    reg [214:0] survivors[0:255];
    reg [214:0] ram_q,ram_data;
    reg [7:0] ram_rd,ram_wr;
    reg ram_we;
    always @(posedge clk) begin
        ram_q<=survivors[ram_rd];
        if(ram_we) survivors[ram_wr]<=ram_data;
    end
    // metric, encoder state, parent index, input bit.
    (* ram_style="distributed" *) reg [29:0] candidates[0:127];
    reg [6:0] scan;
    wire [29:0] candidate=candidates[scan];
    reg [29:0] best;
    reg [214:0] parent;
    reg [4:0] state;
    reg [7:0] init_index;
    reg [1:0] banks;
    reg [7:0] count0,count1;
    reg context_id;
    reg [1:0] received,mask;
    reg [5:0] idx,rank;
    reg [14:0] last_state;
    reg last_valid;
    reg [7:0] baseline;
    reg [7:0] fast_base0,fast_base1,fast_best;
    reg fast_bit;
    // A finite GF(2) inverse gives an independent hard-decision state seed.
    // Injecting it with a penalty lets a pruned trellis reacquire mid-stream;
    // it never replaces the best path of an already clean decode.
    reg [31:0] observed00,observed01,observed10,observed11;
    reg [14:0] seed0,seed1,seed_hold;
    wire [31:0] observation0={(branch ? observed10[30:0]:observed00[30:0]),pair[0]};
    wire [31:0] observation1={(branch ? observed11[30:0]:observed01[30:0]),pair[1]};
    wire [31:0] inverse0=k==16 ? 32'h000074c4:
        known[1] ? 32'h0006b5ca:32'h00d6b79f;
    wire [31:0] inverse1=k==16 ? 32'h00005073:
        known[1] ? 32'h00050005:32'h00a008a2;
    wire seed_bit=(^(observation0&inverse0))^(^(observation1&inverse1));
    wire [214:0] source_parent=idx==63 ? {8'd1,seed_hold,192'd0}:ram_q;
    wire [191:0] selected_history=best[6:1]==63 ? 192'd0:ram_q[191:0];
    wire [7:0] fast_base=context_id ? fast_base1:fast_base0;
    wire [15:0] fast_encoder={10'd0,idx};
    wire [1:0] fast_code={(^(fast_encoder&poly1)),(^(fast_encoder&poly0))};
    wire [1:0] fast_error_a=(fast_code^received)&mask;
    wire [1:0] fast_error_b=(fast_code^2'b11^received)&mask;
    wire [7:0] fast_a=parent[214:207]-fast_base+{7'd0,fast_error_a[0]}+{7'd0,fast_error_a[1]};
    wire [7:0] fast_b=ram_q[214:207]-fast_base+{7'd0,fast_error_b[0]}+{7'd0,fast_error_b[1]};
    wire [7:0] fast_metric=fast_a<=fast_b ? fast_a:fast_b;
    wire [191:0] fast_path=fast_a<=fast_b ? parent[191:0]:ram_q[191:0];
    wire [14:0] state_mask=15'h7fff>>(16-k);
    wire [15:0] enc0={source_parent[206:192],1'b0};
    wire [15:0] enc1={parent[206:192],1'b1};
    wire [1:0] code0={(^(enc0&poly1)),(^(enc0&poly0))};
    wire [1:0] code1={(^(enc1&poly1)),(^(enc1&poly0))};
    wire [1:0] error0=(code0^received)&mask,error1=(code1^received)&mask;
    wire [7:0] metric0=source_parent[214:207]>=250 ? 255:
        source_parent[214:207]+{7'd0,error0[0]}+{7'd0,error0[1]};
    wire [7:0] metric1=parent[214:207]>=250 ? 255:
        parent[214:207]+{7'd0,error1[0]}+{7'd0,error1[1]};
    wire remove_candidate=last_valid && candidate[21:7]==last_state;
    wire candidate_we=state==3 || state==4 || (state==6 && remove_candidate);
    wire [6:0] candidate_addr=state==3 ? {idx,1'b0}:state==4 ? {idx,1'b1}:scan;
    wire [29:0] candidate_data=state==3 ? {metric0,enc0[14:0]&state_mask,idx,1'b0}:
        state==4 ? {metric1,enc1[14:0]&state_mask,idx,1'b1}:{8'd255,candidate[21:0]};
    always @(posedge clk) begin
        if(candidate_we) candidates[candidate_addr]<=candidate_data;
    end
    assign ready=(state==0);
    always @(posedge clk) begin
        ram_we<=0;bit_valid<=0;
        if(reset) begin
            state<=16;init_index<=0;banks<=0;count0<=0;count1<=0;
            bit_out<=0;branch_out<=0;cost<=0;ram_rd<=0;
            fast_base0<=0;fast_base1<=0;
            observed00<=0;observed01<=0;observed10<=0;observed11<=0;seed0<=0;seed1<=0;seed_hold<=0;
        end else case(state)
            16: begin
                ram_we<=1;ram_wr<=init_index;
                ram_data<={(k==7 || init_index[5:0]==0) ? 8'd0:8'd255,
                    k==7 ? {9'd0,init_index[5:0]}:15'd0,192'd0};
                if(init_index==255) state<=17;else init_index<=init_index+1'b1;
            end
            17:state<=0;
            0:if(valid) begin
                context_id<=branch;received<=pair;mask<=known;idx<=0;
                fast_best<=255;state<=k==7 ? 18:1;
                seed_hold<=branch ? seed1:seed0;
                if(branch) begin
                    observed10<=observation0;observed11<=observation1;
                    seed1<={seed1[13:0],seed_bit}&state_mask;
                end else begin
                    observed00<=observation0;observed01<=observation1;
                    seed0<={seed0[13:0],seed_bit}&state_mask;
                end
            end
            1:begin ram_rd<={context_id,banks[context_id],idx};state<=2;end
            2:state<=3;
            3:begin
                parent<=source_parent;
                state<=4;
            end
            4:begin
                if(idx==63) begin
                    rank<=0;scan<=0;best<={8'd255,22'd0};last_valid<=0;state<=6;
                end else begin idx<=idx+1'b1;state<=1;end
            end
            5:state<=6;
            6:begin
                // Remove every candidate reaching the last retained state.
                // This is essential: duplicate paths must not consume the beam.
                if(!remove_candidate && candidate[29:22]<best[29:22]) best<=candidate;
                if(scan==127) state<=7;else scan<=scan+1'b1;
            end
            7:begin
                if(rank==0) baseline<=best[29:22];
                last_state<=best[21:7];last_valid<=1;
                ram_rd<={context_id,banks[context_id],best[6:1]};
                if(best[29:22]==255) state<=11;else state<=8;
            end
            8:state<=9;
            9:begin
                ram_we<=1;ram_wr<={context_id,!banks[context_id],rank};
                ram_data<={best[29:22]-baseline,best[21:7],selected_history[190:0],best[0]};
                if(rank==0) begin
                    bit_out<=selected_history[190];branch_out<=context_id;cost<=baseline;
                    bit_valid<=(context_id ? count1:count0)>=191;
                end
                if(rank==63) state<=12;
                else begin rank<=rank+1'b1;scan<=0;best<={8'd255,22'd0};state<=6;end
            end
            11:begin
                ram_we<=1;ram_wr<={context_id,!banks[context_id],rank};
                ram_data<={8'd255,207'd0};
                if(rank==63) state<=12;else rank<=rank+1'b1;
            end
            12:begin
                banks[context_id]<=!banks[context_id];
                if(context_id) begin if(count1<192) count1<=count1+1'b1;end
                else if(count0<192) count0<=count0+1'b1;
                state<=0;
            end
            // Complete K=7 Viterbi: directly visit all 64 successor states.
            // This avoids sorting and leaves ample time at 8PSK1200F rates.
            18:begin ram_rd<={context_id,banks[context_id],1'b0,idx[5:1]};state<=19;end
            19:state<=20;
            20:begin
                parent<=ram_q;
                ram_rd<={context_id,banks[context_id],1'b1,idx[5:1]};state<=21;
            end
            21:state<=22;
            22:begin
                ram_we<=1;ram_wr<={context_id,!banks[context_id],idx};
                ram_data<={fast_metric,9'd0,idx,fast_path[190:0],idx[0]};
                if(fast_metric<fast_best) begin fast_best<=fast_metric;fast_bit<=fast_path[190];end
                if(idx==63) state<=23;else begin idx<=idx+1'b1;state<=18;end
            end
            23:begin
                bit_out<=fast_bit;branch_out<=context_id;cost<=fast_best;
                bit_valid<=(context_id ? count1:count0)>=191;
                banks[context_id]<=!banks[context_id];
                if(context_id) begin
                    fast_base1<=fast_best;if(count1<192) count1<=count1+1'b1;
                end else begin fast_base0<=fast_best;if(count0<192) count0<=count0+1'b1;end
                state<=0;
            end
            default:state<=16;
        endcase
    end
endmodule
`default_nettype wire
