`timescale 1ns/1ps
`default_nettype none
// Time-shared audio channelizer: 50 MHz clock, 16 ksample/s, up to 12 carriers.
module psk_receiver(
    input wire clk, reset, input wire [4:0] mode,
    input wire signed [13:0] sample, input wire sample_valid,
    output wire ready, output wire [7:0] character,
    output wire character_valid, output reg signal_present,
    output reg symbol_valid, output reg [2:0] symbol_value
);
    `include "mode_config.vh"
    `include "rx_fir_coeff.vh"
    wire [1:0] family=mode_family(mode);
    wire [2:0] rate=mode_rate(mode);
    wire qpsk=(family==1),psk8=(family==2);
    wire fec8=psk8 && mode_k(mode)!=0;
    wire [3:0] carriers=mode_carriers(mode);
    wire [5:0] dec_last=rate>=5 ? 0:(6'd32>>rate)-1'b1;
    wire [2:0] shift=rate>=5 ? 0:5-rate;
    wire [5:0] last_tap=rate==6 ? 40:32;
    wire [20:0] clock_step=rate==6 ? 21'd52429:rate==7 ? 21'd80660:21'd65536;
    reg [5:0] state;
    reg [9:0] init_index;
    reg [3:0] car;
    reg signed [13:0] pcm;
    reg [31:0] phases[0:15];
    reg signed [21:0] accum_i[0:15],accum_q[0:15];
    reg signed [15:0] filtered_i[0:15],filtered_q[0:15];
    reg signed [15:0] previous_i[0:15],previous_q[0:15];
    wire signed [11:0] oscillator_i,oscillator_q;
    wire [9:0] sine_index=phases[car][31:22];
    nco_sine oscillator(clk,state==1,sine_index,oscillator_i,oscillator_q);
    reg signed [25:0] mix_i,mix_q;
    reg signed [21:0] ai,aq;
    wire signed [21:0] sum_i=ai+(mix_i>>>11),sum_q=aq+(mix_q>>>11);
    wire signed [15:0] dec_i=sum_i>>>shift,dec_q=sum_q>>>shift;
    reg [5:0] dec_count,wr,tap;
    (* ram_style="block" *) reg [31:0] history[0:1023];
    wire [5:0] hist_pos=wr-tap;
    reg signed [15:0] di,dq,coefficient;
    reg signed [31:0] prod_i,prod_q;
    reg signed [39:0] fir_i,fir_q;
    reg signed [15:0] fi,fq,pi,pq;
    reg signed [31:0] square_i,square_q;
    reg [31:0] block_energy;
    reg [31:0] energies[0:15];
    reg [4:0] energy_index;
    reg [31:0] amplitude,energy_hold;
    reg signed [31:0] difference;
    reg [19:0] symbol_clock;
    reg [31:0] quotient;
    reg [63:0] remainder,divisor;
    reg [5:0] div_count;
    reg negative_error;
    wire [31:0] abs_diff=difference[31] ? -difference:difference;
    wire [20:0] correction={7'd0,quotient[5:0],8'd0};
    wire [20:0] next_clock={1'b0,symbol_clock}+clock_step+
        (negative_error ? correction:-correction);
    reg signed [31:0] dot_a,dot_b,cross_a,cross_b;
    wire signed [32:0] dot={dot_a[31],dot_a}+{dot_b[31],dot_b};
    wire signed [32:0] cross={cross_a[31],cross_a}-{cross_b[31],cross_b};
    wire [32:0] abs_dot=dot[32] ? -dot:dot;
    wire [32:0] abs_cross=cross[32] ? -cross:cross;
    reg [32:0] octant_x,octant_y;
    reg octant_sign_x,octant_sign_y;
    reg [40:0] scaled_x,scaled_y,threshold_x,threshold_y;
    reg [2:0] octant;
    reg [5:0] warmup;
    wire decode_room;
    assign ready=(state==0) && decode_room;
    psk_decode decoder(.clk(clk),.reset(reset || !signal_present),.mode(mode),
        .symbol(symbol_value),.valid(symbol_valid),.room(decode_room),
        .character(character),.character_valid(character_valid));
    function [2:0] gray_symbol;
        input [2:0] a;
        begin case(a)
            0:gray_symbol=0;1:gray_symbol=1;2:gray_symbol=3;3:gray_symbol=2;
            4:gray_symbol=6;5:gray_symbol=7;6:gray_symbol=5;7:gray_symbol=4;
        endcase end
    endfunction
    // Explicit single write ports are needed by the legacy XST RAM inference.
    wire clear_context=(state==31 && init_index<16);
    wire [3:0] context_addr=clear_context ? init_index[3:0]:car;
    wire [9:0] history_addr=state==31 ? init_index:{car,wr};
    wire [31:0] history_data=state==31 ? 32'd0:{dec_i,dec_q};
    always @(posedge clk) begin
        if(state==31 || (state==3 && dec_count==dec_last))
            history[history_addr]<=history_data;
        if(state==4) {di,dq}<=history[{car,hist_pos}];
        if(clear_context || state==1)
            phases[context_addr]<=clear_context ? 32'd0:phases[car]+carrier_step(mode,car);
        if(clear_context || state==3) begin
            accum_i[context_addr]<=(clear_context || dec_count==dec_last) ? 22'd0:sum_i;
            accum_q[context_addr]<=(clear_context || dec_count==dec_last) ? 22'd0:sum_q;
        end
        if(clear_context || state==16) begin
            previous_i[context_addr]<=clear_context ? 16'd0:fi;
            previous_q[context_addr]<=clear_context ? 16'd0:fq;
        end
        if(clear_context || state==10)
            energies[clear_context ? init_index[3:0]:symbol_clock[19:16]]<=
                clear_context ? 32'd0:energy_hold-(energy_hold>>2)+block_energy;
    end
    always @(posedge clk) begin
        symbol_valid<=0;
        if(reset) begin
            state<=31;init_index<=0;car<=0;pcm<=0;dec_count<=0;wr<=0;tap<=0;
            symbol_clock<=0;warmup<=0;signal_present<=0;symbol_value<=0;
        end else case(state)
            // Clear RAM on confirmed mode changes without resettable arrays.
            31: begin
                if(init_index==1023) state<=0;
                else init_index<=init_index+1'b1;
            end
            0: if(sample_valid && decode_room) begin
                pcm<=sample;car<=0;block_energy<=0;state<=1;
            end
            1: begin
                ai<=accum_i[car];aq<=accum_q[car];state<=2;
            end
            2: begin mix_i<=pcm*oscillator_i;mix_q<=pcm*oscillator_q;state<=3;end
            3: begin
                if(dec_count==dec_last) begin
                    tap<=0;fir_i<=0;fir_q<=0;state<=4;
                end else begin
                    if(car==carriers-1) begin dec_count<=dec_count+1'b1;state<=0;end
                    else begin car<=car+1'b1;state<=1;end
                end
            end
            4: begin
                coefficient<=rx_fir_coeff(rate,tap);state<=5;
            end
            5: begin prod_i<=di*coefficient;prod_q<=dq*coefficient;state<=6;end
            6: begin
                fir_i<=fir_i+prod_i;fir_q<=fir_q+prod_q;
                if(tap==last_tap) state<=7;
                else begin tap<=tap+1'b1;state<=4;end
            end
            7: begin fi<=fir_i>>>15;fq<=fir_q>>>15;state<=8;end
            8: begin
                square_i<=fi*fi;square_q<=fq*fq;
                filtered_i[car]<=fi;filtered_q[car]<=fq;state<=9;
            end
            9: begin
                block_energy<=block_energy+((square_i+square_q)>>10);
                if(car==carriers-1) begin
                    dec_count<=0;wr<=wr+1'b1;
                    energy_hold<=energies[symbol_clock[19:16]];state<=10;
                end else begin car<=car+1'b1;state<=1;end
            end
            10: begin
                amplitude<=0;difference<=0;energy_index<=0;state<=11;
            end
            11: begin
                amplitude<=amplitude+energies[energy_index[3:0]];
                if(energy_index<8) difference<=difference+$signed(energies[energy_index[3:0]]);
                else difference<=difference-$signed(energies[energy_index[3:0]]);
                if(energy_index==15) state<=12;
                else energy_index<=energy_index+1'b1;
            end
            12: begin
                remainder<={32'd0,((abs_diff<<5)+(abs_diff<<4)+(abs_diff<<1)+abs_diff)};
                divisor<={1'b0,amplitude,31'd0};quotient<=0;div_count<=0;
                negative_error<=difference[31];state<=13;
                if(amplitude==0) state<=14;
            end
            13: begin
                if(remainder>=divisor) begin
                    remainder<=remainder-divisor;quotient<={quotient[30:0],1'b1};
                end else quotient<={quotient[30:0],1'b0};
                divisor<=divisor>>1;
                if(div_count==31) state<=14;else div_count<=div_count+1'b1;
            end
            14: begin
                symbol_clock<=next_clock[19:0];
                if(next_clock[20]) begin
                    signal_present<=amplitude>32'd256;
                    if(warmup<63) warmup<=warmup+1'b1;
                    car<=0;state<=15;
                end else state<=0;
            end
            15: begin
                fi<=filtered_i[car];fq<=filtered_q[car];
                pi<=previous_i[car];pq<=previous_q[car];state<=16;
            end
            16: begin
                dot_a<=fi*pi;dot_b<=fq*pq;cross_a<=fq*pi;cross_b<=fi*pq;
                state<=17;
            end
            17: begin
                if(psk8) begin
                    octant_x<=abs_dot;octant_y<=abs_cross;
                    octant_sign_x<=dot[32];octant_sign_y<=cross[32];state<=18;
                end else begin
                    if(!qpsk) symbol_value<={2'b00,!dot[32]};
                    else if(abs_dot>=abs_cross) symbol_value<=dot[32] ? 0:2;
                    else symbol_value<=cross[32] ? 3:1;
                    symbol_valid<=signal_present && warmup>=16;
                    if(car==carriers-1) state<=0;else begin car<=car+1'b1;state<=15;end
                end
            end
            18: begin
                scaled_x<={octant_x,8'd0};scaled_y<={octant_y,8'd0};
                threshold_x<=({8'd0,octant_x}<<6)+({8'd0,octant_x}<<5)+
                    ({8'd0,octant_x}<<3)+({8'd0,octant_x}<<1);
                threshold_y<=({8'd0,octant_y}<<6)+({8'd0,octant_y}<<5)+
                    ({8'd0,octant_y}<<3)+({8'd0,octant_y}<<1);state<=19;
            end
            19: begin
                if(scaled_y<threshold_x) octant<=octant_sign_x ? 4:0;
                else if(scaled_x<threshold_y) octant<=octant_sign_y ? 6:2;
                else if(octant_sign_x) octant<=octant_sign_y ? 5:3;
                else octant<=octant_sign_y ? 7:1;
                state<=20;
            end
            20: begin
                symbol_value<=fec8 ? gray_symbol(octant):(octant^3'd4);
                symbol_valid<=signal_present && warmup>=16;state<=0;
            end
            default:state<=31;
        endcase
    end
endmodule
`default_nettype wire

