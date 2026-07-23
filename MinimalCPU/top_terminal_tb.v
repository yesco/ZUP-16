`timescale 1ns/1ps

module top_terminal_tb;

    // Physical Hardware Emulation Probes
    reg        clk_27m;
    reg        rst_n;
    reg        sim_rx;
    wire       sim_tx;
    
    // Video Bus Terminals
    wire [2:0] tmds_p, tmds_n;
    wire [2:0] tmds_clk_p, tmds_clk_n;

    // Simulation Test Scorecard Metrics
    integer errors_found = 0;
    integer chars_written_count = 0;
    integer chars_echoed_count = 0;
    
    // Memory Capture Windows for Row 1
    reg [7:0] row1_vram_capture [0:4];
    reg [7:0] serial_echo_capture [0:4];

    // 1. Instantiate Your Unified Top-Level Core
    top_terminal uut (
        .sys_clk(clk_27m),
        .sys_rst_n(rst_n),
        .uart_rx(sim_rx),
        .uart_tx(sim_tx),
        .tmds_clk_p(tmds_clk_p),   .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_p),       .tmds_data_n(tmds_n)
    );

    // 2. Drive the Tang Nano Onboard 27 MHz Master Crystal Loop
    always begin
        #18.518 clk_27m = ~clk_27m;
    end

    // 3. Electrical UART Transmit Bit Decoder (Monitors raw TX line)
    // Decodes serial pulses back into ASCII to verify the echo functionality
    integer bit_idx;
    reg [7:0] decoded_byte;
    always @(negedge sim_tx) begin
        repeat(117) @(posedge clk_27m); // Advance to the middle of the Start Bit
        repeat(234) @(posedge clk_27m); // Skip to the middle of Data Bit 0
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            decoded_byte[bit_idx] = sim_tx;
            repeat(234) @(posedge clk_27m);
        end
        $display("[ELECTRICAL CHECK] TX Line echoed back character: 0x%h ('%c')", decoded_byte, decoded_byte);
        if (chars_echoed_count < 5) begin
            serial_echo_capture[chars_echoed_count] = decoded_byte;
        end
        chars_echoed_count = chars_echoed_count + 1;
    end

    // 4. Electrical UART Test Injection Core (Drives raw RX line)
    // Simulates an external USB keyboard at 115200 Baud (234 cycles per bit)
    task inject_usb_keystroke;
        input [7:0] ascii_byte;
        integer i;
        begin
            $display("[USB STIMULUS] Pressing key: '%c' (0x%h)", ascii_byte, ascii_byte);
            sim_rx = 1'b0; // Pull line LOW to trigger Start Bit
            repeat(234) @(posedge clk_27m);
            
            for (i = 0; i < 8; i = i + 1) begin
                sim_rx = ascii_byte[i]; // Shift out data bits
                repeat(234) @(posedge clk_27m);
            end
            
            sim_rx = 1'b1; // Pull line HIGH to assert Stop Bit
            repeat(234) @(posedge clk_27m);
            
            // Allow a tiny inter-character padding gap for the CPU state machine to breathe
            repeat(100) @(posedge clk_27m);
        end
    endtask

    // 5. Shared Memory Matrix Tracker
    // Intercepts and monitors every internal memory write operation
    always @(posedge clk_27m) begin
        if (uut.cpu_mem_wr && uut.is_vram_space) begin
            $display("[VRAM INTERNAL CHECK] Write intercepted -> Memory Slot: %0d, ASCII Data: '%c'", 
                     uut.cpu_vram_addr, uut.cpu_mem_dout[7:0]);
            
            // If the write hits our expected Next Line zone (Row 1 starts at 64)
            if (uut.cpu_vram_addr >= 64 && uut.cpu_vram_addr <= 68) begin
                row1_vram_capture[uut.cpu_vram_addr - 64] = uut.cpu_mem_dout[7:0];
            end
            
            // SECURITY CHECK: Fail instantly if the CPU tries to corrupt the top line header
            if (uut.cpu_vram_addr < 64) begin
                $display("[CRITICAL FAULT] CPU incorrectly attempted to overwrite Title Header at Slot %0d!", uut.cpu_vram_addr);
                errors_found = errors_found + 1;
            end
            
            chars_written_count = chars_written_count + 1;
        end
    end

    // 6. Main Automated Grading Procedure
    initial begin
        $display("\n========================================================");
        $display("STARTING COMPUTATIONAL TERMINAL TESTING SUITE...");
        $display("========================================================\n");
        
        // Initialize lines to default idle state
        clk_27m = 1'b0;
        rst_n   = 1'b0;
        sim_rx  = 1'b1; // UART lines rest high when idle
        
        row1_vram_capture[0] = 8'h00; row1_vram_capture[1] = 8'h00;
        row1_vram_capture[2] = 8'h00; row1_vram_capture[3] = 8'h00;
        row1_vram_capture[4] = 8'h00;

        // Hold system reset for a clean clock start
        #500;
        rst_n = 1'b1;
        $display("[STATUS] System Reset Released. Memory structures initialized.");
        
        // --- TEST 1: Verify Title Row 0 Isolation ---
        if (uut.text_vram[0] != "Y" || uut.text_vram[19] != "K") begin
            $display("[FAULT] Header string 'Yesco Terminal TN20K' is corrupted at boot!");
            errors_found = errors_found + 1;
        end else begin
            $display("[SUCCESS] Header string successfully verified on Line 0.");
        end

        // Wait brief setup padding
        repeat(1000) @(posedge clk_27m);

        // --- TEST 2: Inject Sequential USB Keys to Row 1 ---
        // Typing string: "HELLO"
        inject_usb_keystroke(8'h48); // 'H'
        inject_usb_keystroke(8'h45); // 'E'
        inject_usb_keystroke(8'h4C); // 'L'
        inject_usb_keystroke(8'h4C); // 'L'
        inject_usb_keystroke(8'h4F); // 'O'

        // Settle system lines
        repeat(5000) @(posedge clk_27m);

        // =================================================================
        // AUTOMATED SYSTEM SCORECARD GENERATION
        // =================================================================
        $display("\n================== VERIFICATION SCORECARD ==================");
        $display("Line 0 Title String State:       %c%c%c%c%c...", uut.text_vram[0], uut.text_vram[1], uut.text_vram[2], uut.text_vram[3], uut.text_vram[4]);
        $display("Expected Characters on Line 1:   H E L L O");
        $display("Actual Memory Slots [64 to 68]:  %c %c %c %c %c", 
                  row1_vram_capture[0], row1_vram_capture[1], row1_vram_capture[2], row1_vram_capture[3], row1_vram_capture[4]);
        $display("Decoded USB Serial Loop Echoes:  %c %c %c %c %c",
                  serial_echo_capture[0], serial_echo_capture[1], serial_echo_capture[2], serial_echo_capture[3], serial_echo_capture[4]);
        $display("------------------------------------------------------------");
        $display("Total Hardware Matrix Writes:    %0d / 5", chars_written_count);
        $display("Total Monitored Serial Echoes:   %0d / 5", chars_echoed_count);
        
        // Verify both conditions programmatically
        if (row1_vram_capture[0] == "H" && row1_vram_capture[1] == "E" && 
            row1_vram_capture[2] == "L" && row1_vram_capture[3] == "L" && 
            row1_vram_capture[4] == "O" && chars_echoed_count == 5 && errors_found == 0) begin
            $display("\nFINAL RESULT: [PASS] System bus layout, positioning, and echoes are 100%% verified.");
        end else begin
            $display("\nFINAL RESULT: [FAIL] Timing race or cursor layout positioning fault detected!");
        end
        $display("============================================================\n");
        $finish;
    end

endmodule
