`timescale 1ns/1ps

module top_terminal_tb;

    reg        clk_27m;
    reg        rst_n;
    reg        sim_rx;
    wire       sim_tx;
    
    wire [2:0] tmds_p, tmds_n;
    wire [2:0] tmds_clk_p, tmds_clk_n;

    // Tracker variables to score the simulation success
    integer chars_written_to_vram = 0;
    integer chars_echoed_over_uart = 0;
    reg [7:0] last_vram_char_0 = 8'h00;
    reg [7:0] last_vram_char_1 = 8'h00;

    top_terminal uut (
        .sys_clk(clk_27m),
        .sys_rst_n(rst_n),
        .uart_rx(sim_rx),
        .uart_tx(sim_tx),
        .tmds_clk_p(tmds_clk_p),   .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_p),       .tmds_data_n(tmds_n)
    );

    // Clock generator (27 MHz)
    always begin
        #18.518 clk_27m = ~clk_27m;
    end

    // UART Tx Bit Decoder (Watches the TX line to count echoed characters)
    // 115200 Baud = ~234 clock cycles per bit
    integer bit_idx;
    reg [7:0] decoded_tx_byte;
    always @(negedge sim_tx) begin
        // Detected a start bit on echo line!
        repeat(117) @(posedge clk_27m); // Jump to middle of start bit
        repeat(234) @(posedge clk_27m); // Skip to middle of first data bit
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            decoded_tx_byte[bit_idx] = sim_tx;
            repeat(234) @(posedge clk_27m);
        end
        $display("[ECHO CHECK] Host PC received echo byte: 0x%h ('%c')", decoded_tx_byte, decoded_tx_byte);
        chars_echoed_over_uart = chars_echoed_over_uart + 1;
    end

    // Standard task to push character inputs into the RX line
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            sim_rx = 1'b0; // Start Bit
            repeat(234) @(posedge clk_27m);
            for (i = 0; i < 8; i = i + 1) begin
                sim_rx = data[i];
                repeat(234) @(posedge clk_27m);
            end
            sim_rx = 1'b1; // Stop Bit
            repeat(234) @(posedge clk_27m);
        end
    endtask

    // Monitoring block for VRAM screen writes
    always @(posedge clk_27m) begin
        if (uut.cpu_mem_wr && uut.is_vram_space) begin
            $display("[VRAM CHECK] Screen Matrix Write -> Slot: 0x%h Data: '%c'", uut.cpu_vram_addr, uut.cpu_mem_dout[7:0]);
            if (uut.cpu_vram_addr == 11'd0) last_vram_char_0 = uut.cpu_mem_dout[7:0];
            if (uut.cpu_vram_addr == 11'd1) last_vram_char_1 = uut.cpu_mem_dout[7:0];
            chars_written_to_vram = chars_written_to_vram + 1;
        end
    end

    initial begin
        clk_27m = 1'b0;
        rst_n   = 1'b0;
        sim_rx  = 1'b1;

        #200;
        rst_n = 1'b1;
        #2000;

        // Fire back-to-back keystrokes
        $display("[SIM] Sending 'H'...");
        send_uart_byte(8'h48);
        
        // Wait a small window for the CPU loop to clear before next character arrives
        repeat(500) @(posedge clk_27m);

        $display("[SIM] Sending 'I'...");
        send_uart_byte(8'h49);

        // Let the simulation settle
        repeat(3000) @(posedge clk_27m);

        // =================================================================
        // SYSTEM SCORECARD VALIDATION
        // =================================================================
        $display("\n============= SIMULATION SCORECARD =============");
        $display("Expected Screen Characters: Slot 0 = 'H', Slot 1 = 'I'");
        $display("Actual Screen Characters:   Slot 0 = '%c', Slot 1 = '%c'", last_vram_char_0, last_vram_char_1);
        $display("Total VRAM writes registered: %0d / 2", chars_written_to_vram);
        $display("Total Echoes caught on TX:    %0d / 2", chars_echoed_over_uart);
        
        if (last_vram_char_0 == "H" && last_vram_char_1 == "I" && chars_echoed_over_uart == 2) begin
            $display("RESULT: SUCCESS - Core terminal bus is verified.");
        end else begin
            $display("RESULT: FAILED - Missing data, drops, or collisions detected.");
        end
        $display("================================================\n");
        $finish;
    end

endmodule
