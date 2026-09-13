`timescale 1ns/1ps
module tb_rotary;
    `include "mode_config.vh"
    reg clk=0;always #10 clk=~clk;
    reg [1:0] ab=0;
    reg button=0;
    wire [4:0] active_mode,pending_mode;
    wire editing,applied;
    integer commits=0,i;
    rotary_mode #(.ROT_FILTER_CYCLES(16),.BUTTON_FILTER_CYCLES(40))
        dut(clk,ab[1],ab[0],button,active_mode,pending_mode,editing,applied);
    always @(posedge clk) if(applied) commits=commits+1;
    task fail;
        input [511:0] why;
        begin $display("FAIL %s",why);$finish;end
    endtask
    task contact;
        input [1:0] value;
        reg [1:0] old_value;
        begin
            old_value=ab;
            @(negedge clk);ab=value;
            repeat(4) @(negedge clk);ab=old_value;
            repeat(4) @(negedge clk);ab=value;
            repeat(80) @(negedge clk);
        end
    endtask
    task cw;
        begin contact(2'b10);contact(2'b11);contact(2'b01);contact(2'b00);end
    endtask
    task ccw;
        begin contact(2'b01);contact(2'b11);contact(2'b10);contact(2'b00);end
    endtask
    task press;
        begin
            button=1;repeat(5) @(negedge clk);
            button=0;repeat(5) @(negedge clk);
            button=1;repeat(100) @(negedge clk);
        end
    endtask
    task release_button;
        begin button=0;repeat(100) @(negedge clk);end
    endtask
    initial begin
        repeat(100) @(negedge clk);
        if(active_mode!=0 || pending_mode!=0 || editing) fail("startup");
        // Reversing halfway and illegal skipped states must not select a mode.
        contact(2'b10);contact(2'b11);contact(2'b10);contact(2'b00);
        contact(2'b11);contact(2'b00);
        if(pending_mode!=0 || editing) fail("partial/illegal turn counted");
        cw();
        if(pending_mode!=1 || active_mode!=0 || !editing || commits!=0) fail("preview applied too soon");
        press();
        if(active_mode!=1 || editing || commits!=1) fail("confirm");
        repeat(1000) @(negedge clk);
        if(commits!=1) fail("held button repeated");
        // Turning while the knob is pressed must not open/change the menu.
        cw();
        if(pending_mode!=1 || editing) fail("press/turn collision");
        release_button();
        for(i=0;i<`PSK_MODE_COUNT-1;i=i+1) begin
            cw();
            if(pending_mode!=((i+2)%`PSK_MODE_COUNT) || active_mode!=1) fail("mode cycle");
        end
        press();release_button();
        if(active_mode!=0 || commits!=2) fail("clockwise wrap");
        ccw();
        if(pending_mode!=`PSK_MODE_COUNT-1 || active_mode!=0) fail("counterclockwise wrap");
        press();release_button();
        if(active_mode!=`PSK_MODE_COUNT-1 || commits!=3) fail("last mode selection");
        // Idle presses and previewing back to the active mode preserve decode.
        press();release_button();
        if(commits!=3) fail("idle press reset");
        cw();ccw();press();release_button();
        if(editing || active_mode!=`PSK_MODE_COUNT-1 || commits!=3) fail("same-mode confirm reset");
        $display("PASS rotary bounce, direction, wrap, preview/confirm, held button");
        $finish;
    end
endmodule
