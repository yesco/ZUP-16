`timescale 1ns/1ps

module top_terminal_tb;

    // Testbench Driver Registers
    reg        clk_27m;
    reg        rst_n;
    reg        sim_rx;
    wire       sim_tx;
    
    // Video Output Tracking Wires
    wire [2:0] tmds_p, tmds_n;
    wire [2:0] tmds_clk_p, tmds_clk_n;

    // 1. Instantiate the Master Top Module under analysis
    top_terminal uut (
        .sys_clk(clk_27m),
        .sys_rst_n(rst_n),
        .uart_rx(sim_rx),
        .uart_tx(sim_tx),
        .tmds_clk_p(tmds_clk_p),   .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_p),       .tmds_data_n(tmds_n)
    );

    // 2. Generate 27 MHz Base Reference System Clock Cycle (~37.037 ns period)
    always begin
        #18.518 clk_27m = ~clk_27m;
    end

    // Helper task to automatically push a single data byte through the RX pin
    // Emulates standard 115200 Baud UART framing sequence (234 reference clock cycles per bit)
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // A. Drive Low Start Bit
            sim_rx = 1'b0;
            repeat(234) @(posedge clk_27m);
            
            // B. Shift out 8 Data payload bits (LSB First)
            for (i = 0; i < 8; i = i + 1) begin
                sim_rx = data[i];
                repeat(234) @(posedge clk_27m);
            end
            
            // C. Drive High Stop Bit
            sim_rx = 1'b1;
            repeat(234) @(posedge clk_27m);
        end
    endtask

    // 3. Execution Simulation Procedure Block
    initial begin
        // Display Tracking header
        $display("[SIM START] Initializing Terminal System Core Verification...");
        
        // Initialize Core System Pins
        clk_27m = 1'b0;
        rst_n   = 1'b0;
        sim_rx  = 1'b1; // Idle serial line rests high

        // Assert system reset condition
        #200;
        rst_n = 1'b1;
        $display("[SIM STATUS] Hardware Reset Released.");

        // Wait brief stability padding
        #1000;

        // Transmit Character ASCII 'H' (Hex 8'h48)
        $display("[SIM STIMULUS] Injecting Serial Byte: 'H' (0x48)");
        send_uart_byte(8'h48);
        
        // Transmit Character ASCII 'I' (Hex 8'h49)
        $display("[SIM STIMULUS] Injecting Serial Byte: 'I' (0x49)");
        send_uart_byte(8'h49);

        // Allow execution cycle window for the CPU to digest the data packet and draw to screen VRAM
        repeat(2000) @(posedge clk_27m);

        // Simulation completed cleanly
        $display("[SIM SUCCESS] Data Stream completed. Review out log files.");
        $finish;
    end

    // 4. Capture Output changes to print to the generated console log file
    always @(posedge clk_27m) begin
        if (uut.uart_rx_ready) begin
            $display("[SIM MONITOR] Bus Notification: UART Received Byte data = 0x%h ('%c')", 
                     uut.uart_rx_byte, uut.uart_rx_byte);
        end
        if (uut.cpu_mem_wr && uut.is_vram_space) begin
            $display("[SIM MONITOR] VRAM Allocation Written: Address Offset=0x%h, Character Byte Data=0x%h", 
                     uut.cpu_vram_addr, uut.cpu_mem_dout[7:0]);
        end
    end

endmodule
