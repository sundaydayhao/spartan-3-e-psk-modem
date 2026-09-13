`timescale 1ns/1ps
`default_nettype none
// UG230 chapter 10. LTC6912-1 gain -1 on A/B; LTC1407A-1 signed samples.
// SPI SCK = 5 MHz, conversion rate = 50 MHz / 3125 = 16 kHz.
module adc_capture(input wire clk,input wire miso,
    output reg sck=0,mosi=0,amp_cs=1,conv=0,
    output wire amp_shdn,
    output reg signed [13:0] sample_a=0,sample_b=0,
    output reg sample_valid=0,ready=0);
    reg [2:0] state=0,divider=0;
    reg [15:0] delay_count=0;
    reg [3:0] bit_count=0;
    reg [7:0] gain=8'h11;
    reg [9:0] slot=0;
    reg [13:0] shift_a=0,shift_b=0;
    reg first_conversion=1;
    (* ASYNC_REG="TRUE" *) reg miso_meta=0,miso_sync=0;
    assign amp_shdn=0;
    always @(posedge clk) begin
        miso_meta<=miso;miso_sync<=miso_meta;sample_valid<=0;
        if(divider==4) begin
            divider<=0;
            case(state)
                0: if(delay_count==9999) begin
                    delay_count<=0;amp_cs<=0;mosi<=gain[7];state<=1;
                end else delay_count<=delay_count+1'b1;
                1: if(!sck) sck<=1;
                   else begin
                       sck<=0;gain<={gain[6:0],1'b0};mosi<=gain[6];
                       if(bit_count==7) begin amp_cs<=1;state<=2;end
                       else bit_count<=bit_count+1'b1;
                   end
                2: if(delay_count==9999) begin delay_count<=0;slot<=0;state<=3;end
                   else delay_count<=delay_count+1'b1;
                3: begin
                    if(slot==624) slot<=0; else slot<=slot+1'b1;
                    if(slot==0) conv<=1;
                    if(slot==1) conv<=0;
                    if(slot>=2 && slot<=69) begin
                        sck<=!slot[0];
                        // Data changes just after rising edge 3 (D13) through
                        // 16 (D0), then 19..32. Sample at the following falling
                        // edge, after the two-flop input synchronizer settles.
                        if(slot[0] && slot>=7 && slot<=33) shift_a<={shift_a[12:0],miso_sync};
                        if(slot[0] && slot>=39 && slot<=65) shift_b<={shift_b[12:0],miso_sync};
                    end
                    if(slot==70) begin
                        sample_a<=shift_a;sample_b<=shift_b;
                        first_conversion<=0;
                        if(!first_conversion) begin sample_valid<=1;ready<=1;end
                    end
                end
                default:state<=0;
            endcase
        end else divider<=divider+1'b1;
    end
endmodule
`default_nettype wire
