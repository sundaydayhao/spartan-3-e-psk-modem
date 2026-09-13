`timescale 1ns/1ps
module tb_board;
    reg clk=0;always #10 clk=~clk;
    reg [1:0] rotary=0;
    reg button=0;
    reg miso=1'bz;
    wire sck,mosi,amp_cs,amp_shdn,conv,spi_cs,dac_cs,dac_clr,init_b;
    wire [7:0] led;
    wire [3:0] lcd_data;
    wire lcd_e,lcd_rs,lcd_rw,ce,oe,we;
    psk_rx_top dut(clk,rotary[1],rotary[0],button,miso,sck,mosi,amp_cs,amp_shdn,conv,
        spi_cs,dac_cs,dac_clr,init_b,led,lcd_data,lcd_e,lcd_rs,lcd_rw,ce,oe,we);
    integer conversions=0,edges=0,gain_bits=0,checks=0;
    reg [7:0] gain=0;
    reg [13:0] a=0,b=0;
    time last_conv=0,conv_start=0,sck_rise=0,lcd_rise=0;
    reg [3:0] lcd_high;
    reg half=0;
    reg [7:0] command;
    integer boot=0,address=0,frames=0;
    reg [127:0] row1=0,row2=0;
    task fail;
        input [255:0] why;
        begin $display("FAIL %s",why);$finish;end
    endtask
    task clockwise;
        begin
            rotary=2'b10;#2000000;rotary=2'b11;#2000000;
            rotary=2'b01;#2000000;rotary=2'b00;#2000000;
        end
    endtask
    task confirm_mode;
        begin button=1;#30000000;button=0;#80000000;end
    endtask
    always @(posedge conv) begin
        if(conversions>0) begin
            if($time-last_conv!=62500) fail("ADC sample period");
            if(edges!=34) fail("ADC not 34 clocks");
        end
        last_conv=$time;conv_start=$time;edges=0;conversions=conversions+1;
        a=-1234+conversions;b=2345-conversions;
    end
    always @(negedge conv) if(conversions>0 && $time-conv_start<4) fail("CONV pulse width");
    always @(posedge sck) begin
        sck_rise=$time;
        if(!amp_cs) begin gain={gain[6:0],mosi};gain_bits=gain_bits+1;end
        else if(conversions>0) begin
            edges=edges+1;
            if(edges>=3 && edges<=16) #8 miso=a[16-edges];
            else if(edges>=19 && edges<=32) #8 miso=b[32-edges];
            else #8 miso=1'bz;
        end
    end
    always @(negedge sck) if(sck_rise>0 && $time-sck_rise<100) fail("SPI high width");
    always @(posedge amp_cs) if(gain_bits>0 && (gain_bits!=8 || gain!==8'h11)) fail("Amplifier gain command");
    always @(posedge clk) begin
        if(!spi_cs || !dac_cs || !dac_clr || init_b || !ce || !oe || !we || amp_shdn)
            fail("Shared bus isolation");
        if(dut.sample_valid) begin
            checks=checks+1;
            if(conversions<2) fail("ADC first conversion used");
            if(dut.sample_a!==a || dut.sample_b!==b) fail("ADC channel/sign/framing");
        end
        if(led[6]) fail("receiver overrun");
    end
    // Monitor actual LCD pins, including 4-bit bootstrap and DDRAM addressing.
    always @(posedge lcd_e) lcd_rise=$time;
    always @(negedge lcd_e) if(lcd_rise>0) begin
        if(lcd_rw || $time-lcd_rise<1000) fail("LCD bus timing");
        if(boot<4) begin
            if((boot<3 && lcd_data!=3) || (boot==3 && lcd_data!=2)) fail("LCD bootstrap");
            boot=boot+1;
        end else if(!half) begin lcd_high=lcd_data;half=1;end
        else begin
            command={lcd_high,lcd_data};half=0;
            if(!lcd_rs) begin
                if(command[7]) address=command&127;
                else if(command==1) begin row1="                ";row2="                ";address=0;end
            end else begin
                if(address<16) row1[(15-address)*8+:8]=command;
                else if(address>=64 && address<80) row2[(79-address)*8+:8]=command;
                address=address+1;
                if(address==80) frames=frames+1;
            end
        end
    end
    initial begin
        #150000000;
        if(row1!=="BPSK31    2k ---") fail("LCD initial mode line");
        // Inject only at the decoder's character interface to separately test
        // presentation; waveform decoding is covered by tb_receiver.
        @(negedge clk);force dut.character_valid=1;force dut.character=8'h48;
        @(negedge clk);release dut.character_valid;release dut.character;
        #70000000;
        if(row2[7:0]!==8'h48) begin
            $display("row2=%s internal=%s",row2,dut.text_line);
            fail("LCD decoded character");
        end
        clockwise();
        #70000000;
        if(row1!==">BPSK63    PUSH ") fail("LCD preview mode");
        if(dut.rx.rate!==0 || dut.rx.qpsk!==0 || row2[7:0]!==8'h48)
            fail("preview changed receiver/text");
        confirm_mode();
        if(row1[127:24]!=="BPSK63    2k ") fail("LCD confirmed BPSK mode");
        if(dut.rx.rate!==1 || dut.rx.qpsk!==0) fail("BPSK confirmed routing");
        if(row2!=="                ") fail("mode change clears text");
        repeat(5) clockwise(); // BPSK125/250/500/1000 then QPSK31
        if(dut.rx.rate!==1 || dut.rx.qpsk!==0) fail("QPSK preview applied");
        confirm_mode();
        if(row1[127:24]!=="QPSK31    2k ") fail("LCD confirmed QPSK mode");
        if(dut.rx.rate!==0 || dut.rx.qpsk!==1) fail("QPSK confirmed routing");
        if(!led[4] || led[5]) fail("active/pending LEDs");
        repeat(20) clockwise(); // Last mode, 8PSK1200F
        #70000000;
        if(row1!==">8PSK1200F PUSH ") fail("LCD 9-character mode preview");
        if(dut.rx.family!==1 || dut.rx.rate!==0) fail("8PSK preview applied");
        confirm_mode();
        if(row1[127:24]!=="8PSK1200F 2k ") fail("LCD confirmed 8PSK mode");
        if(dut.rx.family!==2 || dut.rx.rate!==7) fail("8PSK1200F confirmed routing");
        if(checks<100 || frames<3) fail("insufficient board coverage");
        $display("PASS ADC gain/framing/rate, bus isolation, LCD text/modes, no overrun");
        $finish;
    end
endmodule
