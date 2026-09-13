`timescale 1ns/1ps
module tb_receiver;
    `include "mode_config.vh"
`ifdef STRESS
    localparam VECTOR_DIR="../psk-stress/";
`else
    localparam VECTOR_DIR="../psk-vectors/";
`endif
    parameter FIRST_MODE=0,LAST_MODE=`PSK_MODE_COUNT;
    reg clk=0; always #10 clk=~clk;
    reg reset=1;
    reg [4:0] mode=0;
    reg signed [13:0] sample=0;
    reg sample_valid=0;
    wire ready,character_valid,signal_present,symbol_valid;
    wire [7:0] character;
    wire [2:0] symbol_value;
    psk_receiver dut(clk,reset,mode,sample,sample_valid,ready,
        character,character_valid,signal_present,symbol_valid,symbol_value);
    reg [13:0] samples[0:639999];
    integer mode_index,n,f,cycles,frames,max_busy,demod_cycles,max_demod,fec_cycles,max_fec;
    always @(posedge clk) if(character_valid) $fwrite(f,"%c",character);
    always @(posedge clk) if(!reset && sample_valid && !ready) begin
        $display("FAIL stimulus violated sample ready handshake");$finish;
    end
    always @(posedge clk) begin
        if(reset) begin demod_cycles=0;max_demod=0;fec_cycles=0;max_fec=0;end
        else begin
            if(dut.state!=0 && dut.state!=31) demod_cycles=demod_cycles+1;
            else begin if(demod_cycles>max_demod)max_demod=demod_cycles;demod_cycles=0;end
            if(signal_present && !dut.decoder.fec_ready) fec_cycles=fec_cycles+1;
            else begin if(fec_cycles>max_fec)max_fec=fec_cycles;fec_cycles=0;end
        end
    end
    initial begin
        for(mode_index=FIRST_MODE;mode_index<LAST_MODE;mode_index=mode_index+1) begin
            reset=1;sample_valid=0;mode=mode_index;max_busy=0;
            `include "../../sim/psk/vector_files.vh"
            repeat(5) @(negedge clk); reset=0;
            while(!ready) @(negedge clk);
            // Deliberately start between carrier/sample/symbol boundaries.
            for(n=137;n<frames;n=n+1) begin
                // The previous symbol enters the decoder FIFO one clock after
                // the channelizer becomes idle. Recheck room immediately before
                // sending, rather than relying on the previous loop's ready.
                while(!ready) @(negedge clk);
                sample=samples[n];sample_valid=1;
                @(negedge clk);sample_valid=0;
                cycles=0;
                while(!ready) begin
                    @(negedge clk);cycles=cycles+1;
                    if(cycles>100000) begin $display("FAIL busy timeout");$finish;end
                end
                if(cycles>max_busy) max_busy=cycles;
                @(negedge clk);
            end
            repeat(200000) @(negedge clk);
            if(dut.decoder.overflow) begin $display("FAIL decoder FIFO overflow");$finish;end
            if(max_demod>=3125) begin $display("FAIL ADC processing deadline");$finish;end
            if(max_fec>10000) begin $display("FAIL FEC pair deadline");$finish;end
            $fclose(f);$display("MODE %0d complete, max busy %0d, demod %0d, FEC %0d clocks",
                mode,max_busy,max_demod,max_fec);
        end
        $display("PASS RTL waveform run completed");$finish;
    end
endmodule
