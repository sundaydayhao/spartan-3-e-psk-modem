`timescale 1ns/1ps
module tb_fec;
    parameter MODE=15,COUNT=3000,SKIP=17;
    reg clk=0;always #10 clk=~clk;
    reg reset=1,valid=0;
    reg [2:0] symbol;
    wire room,character_valid;
    wire [7:0] character;
    psk_decode dut(clk,reset,MODE[4:0],symbol,valid,room,character,character_valid);
    reg [2:0] symbols[0:3999];
    integer n,f,cycles;
    always @(posedge clk) if(character_valid) $fwrite(f,"%c",character);
    initial begin
        $readmemh("symbols.hex",symbols,0,COUNT-1);
        f=$fopen("decoded.txt","w");
        repeat(5) @(negedge clk);reset=0;
        // Join between pair boundaries: both unpunctured alignments must work.
        for(n=SKIP;n<COUNT;n=n+1) begin
            while(!room) @(negedge clk);
            symbol=symbols[n];valid=1;@(negedge clk);valid=0;
            repeat(15) @(negedge clk);
        end
        cycles=0;
        while(dut.wp!=dut.rp || dut.state!=0 || !dut.fec_ready) begin
            @(negedge clk);cycles=cycles+1;
            if(cycles>300000)begin $display("FAIL drain timeout");$finish;end
        end
        repeat(100) @(negedge clk);$fclose(f);
        if(dut.overflow)begin $display("FAIL symbol overflow");$finish;end
        $display("PASS FEC symbol run, branch=%d score=%d/%d",dut.selected,dut.score0,dut.score1);
        $finish;
    end
endmodule
