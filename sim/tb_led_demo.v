`timescale 1ns / 1ps
module tb_led_demo;
    reg clk = 0;
    always #10 clk = ~clk;
    wire [7:0] led;
    wire [3:0] data;
    wire en, rs, rw, ce, oe, we;
    led_demo dut(clk, led, data, en, rs, rw, ce, oe, we);
    integer errors = 0, bootstrap = 0, bytes_seen = 0, address = 0;
    reg half = 0;
    reg [3:0] high_nibble;
    reg high_rs;
    reg [7:0] value;
    reg [7:0] ddram [0:127];
    reg [127:0] first_line, second_line;
    time bus_change = 0, rise_time = 0, previous_fall = 0;
    time previous_byte = 0;
    integer required_gap = 0;
    integer i;

    task fail;
        input [511:0] reason;
        begin
            errors = errors + 1;
            $display("FAIL at %0t: %0s", $time, reason);
        end
    endtask

    always @(data or rs or rw) begin
        if (en === 1'b1) fail("LCD bus changed while E was high");
        bus_change = $time;
    end
    always @(posedge en) begin
        if ($time - bus_change < 40) fail("LCD setup below 40 ns");
        if (previous_fall != 0 && $time - previous_fall < 1000)
            fail("LCD inter-nibble gap below 1 us");
        rise_time = $time;
    end
    always @(negedge en) begin
        if ($time > 0) begin
            if ($time - rise_time < 230) fail("E pulse below 230 ns");
            if (rw !== 0 || ce !== 1 || oe !== 1 || we !== 1)
                fail("LCD write mode or Flash disable incorrect");
            previous_fall = $time;
            if (bootstrap < 4) begin
                if (rs !== 0 || data !== ((bootstrap == 3) ? 4'h2 : 4'h3))
                    fail("Incorrect 3,3,3,2 bootstrap");
                case (bootstrap)
                    0: if ($time < 15000000) fail("Power-on wait below 15 ms");
                    1: if ($time - previous_byte < 4100000) fail("Bootstrap wait below 4.1 ms");
                    2: if ($time - previous_byte < 100000) fail("Bootstrap wait below 100 us");
                    3: if ($time - previous_byte < 40000) fail("Bootstrap wait below 40 us");
                endcase
                bootstrap = bootstrap + 1;
                previous_byte = $time;
                required_gap = 40000;
            end else if (!half) begin
                if ($time - previous_byte < required_gap)
                    fail("Command execution wait too short");
                high_nibble = data;
                high_rs = rs;
                half = 1;
            end else begin
                if (rs !== high_rs) fail("RS changed between byte nibbles");
                value = {high_nibble, data};
                case (bytes_seen)
                    0: if (rs || value != 8'h28) fail("Missing function set");
                    1: if (rs || value != 8'h06) fail("Missing entry mode");
                    2: if (rs || value != 8'h0c) fail("Missing display on");
                    3: if (rs || value != 8'h01) fail("Missing clear");
                    4: if (rs || value != 8'h80) fail("Missing first row address");
                    21: if (rs || value != 8'hc0) fail("Missing second row address");
                    default: if (!rs) fail("Expected character data");
                endcase
                if (rs) begin
                    ddram[address] = value;
                    address = address + 1;
                end else if (value[7]) address = value[6:0];
                else if (value == 8'h01) begin
                    for (i = 0; i < 128; i = i + 1) ddram[i] = 8'h20;
                    address = 0;
                end
                previous_byte = $time;
                required_gap = (!rs && value == 8'h01) ? 1640000 : 40000;
                bytes_seen = bytes_seen + 1;
                half = 0;
            end
        end
    end

    initial begin
        #60000000;
        first_line = 0;
        second_line = 0;
        for (i = 0; i < 16; i = i + 1) begin
            first_line = {first_line[119:0], ddram[i]};
            second_line = {second_line[119:0], ddram[64+i]};
        end
        if (first_line !== "SPARTAN-3E READY") fail("First LCD line mismatch");
        if (second_line !== "Hello, FPGA!    ") fail("Second LCD line mismatch");
        if (bytes_seen != 38 || half || en || led !== 8'h03)
            fail("Transfer count, idle E or LED status incorrect");
        $display("LCD line 1: [%0s]", first_line);
        $display("LCD line 2: [%0s]", second_line);
        // Exercise the actual 25-million-cycle divider at its rollover.
        @(negedge clk); dut.count = 25'd24999998;
        repeat (2) @(posedge clk);
        #1;
        if (led !== 8'h83 || dut.count !== 0) fail("LED heartbeat rollover failed");
        if (errors == 0) $display("PASS: LCD initialization, timing, text, Flash isolation and LEDs");
        else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
