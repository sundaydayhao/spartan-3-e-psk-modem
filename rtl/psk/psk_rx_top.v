`timescale 1ns/1ps
`default_nettype none
module psk_rx_top(input wire clk_50mhz,input wire rot_a,rot_b,rot_center,
    input wire spi_miso,
    output wire spi_sck,spi_mosi,amp_cs,amp_shdn,ad_conv,
    output wire spi_ss_b,dac_cs,dac_clr,fpga_init_b,
    output wire [7:0] led,output wire [3:0] lcd_data,
    output wire lcd_e,lcd_rs,lcd_rw,sf_ce0,sf_oe,sf_we);
    assign spi_ss_b=1;assign dac_cs=1;assign dac_clr=1;
    // Platform Flash otherwise drives the shared MISO after master-serial boot.
    assign fpga_init_b=0;
    assign sf_ce0=1;assign sf_oe=1;assign sf_we=1;
    `include "mode_config.vh"
    wire [4:0] selection,pending_mode;
    wire editing,change;
    rotary_mode controls(clk_50mhz,rot_a,rot_b,rot_center,
        selection,pending_mode,editing,change);
    reg [5:0] startup=0;
    wire reset=(!(&startup)) || change;
    always @(posedge clk_50mhz) begin
        if(!(&startup)) startup<=startup+1'b1;
    end
    wire signed [13:0] sample_a,sample_b;
    wire sample_valid,adc_ready,rx_ready,signal_present;
    wire [7:0] character;
    wire character_valid,symbol_valid;
    wire [2:0] symbol_value;
    adc_capture adc(clk_50mhz,spi_miso,spi_sck,spi_mosi,amp_cs,ad_conv,
        amp_shdn,sample_a,sample_b,sample_valid,adc_ready);
    psk_receiver rx(clk_50mhz,reset,selection,
        sample_a,sample_valid,rx_ready,
        character,character_valid,signal_present,symbol_valid,symbol_value);
    reg [127:0] text_line="                ";
    reg [23:0] activity=0;
    reg [25:0] heartbeat=0;
    reg overrun=0;
    reg [10:0] settle=2047;
    always @(posedge clk_50mhz) begin
        if(reset) settle<=2047;else if(settle!=0) settle<=settle-1'b1;
    end
    always @(posedge clk_50mhz) begin
        heartbeat<=heartbeat+1'b1;
        if(activity!=0) activity<=activity-1'b1;
        if(reset) begin text_line<="                ";overrun<=0;activity<=0;end
        else begin
            if(sample_valid && !rx_ready && settle==0) overrun<=1;
            if(character_valid) begin
                activity<=24'd10000000;
                if(character==10 || character==13) text_line<="                ";
                else if(character>=32 && character<=126) text_line<={text_line[119:0],character};
            end
        end
    end
    wire [127:0] status_line=editing ? {">",mode_label(pending_mode)," PUSH "} :
        {mode_label(selection)," 2k ",signal_present ? "SIG":"---"};
    wire lcd_ready;
    lcd_live lcd(clk_50mhz,status_line,change ? "                ":text_line,
        lcd_data,lcd_e,lcd_rs,lcd_rw,lcd_ready);
    assign led={heartbeat[25],overrun,editing,(mode_family(selection)!=0),
        (activity!=0),signal_present,adc_ready,lcd_ready};
endmodule
`default_nettype wire
