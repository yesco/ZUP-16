// =========================================================================
// Universal Mock CPU Engine (Immediate Single-Cycle Pass-Through)
// Feature Added: Full VRAM Screen Redraw Matrix Scan on CTRL-L (0x0C)
// =========================================================================

module mock_terminal_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [15:0] mem_addr,
    output reg  [15:0] mem_dout,
    input  wire [15:0] mem_din,
    output reg         mem_wr
);
    reg [2:0]  state;
    reg [10:0] cursor_ptr;
    reg [7:0]  live_key;
    
    // Dedicated VRAM Scanner Registers for Screen Redraw
    reg [10:0] scan_ptr;
    wire [5:0] scan_col = scan_ptr % 64;

    // Helper wires to breakdown cursor positioning (64 columns per row)
    wire [4:0] current_row = cursor_ptr / 64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr    <= 16'h8002; // Monitor UART Status Register
            mem_dout    <= 16'h0000;
            mem_wr      <= 1'b0;
            state       <= 3'd0;
            cursor_ptr  <= 11'd64;   // Starts on Row 1, Col 0
            live_key    <= 8'h00;
            scan_ptr    <= 11'd0;
        end else begin
            case (state)
                3'd0: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002; 
                    
                    // If Bit 0 (rx_data_valid) is high, jump instantly to read the character
                    if (mem_din == 1'b1) begin 
                        mem_addr <= 16'h8000; 
                        state    <= 3'd1;
                    end
                end

                3'd1: begin
                    // State 1: Capture the live key from the data bus
                    live_key <= mem_din[7:0];
                    mem_wr   <= 1'b0;
                    
                    // INTERCEPT INTERRUPT: Detect Ctrl+L (Form Feed / ASCII 0x0C)
                    if (mem_din[7:0] == 8'h0C) begin
                        scan_ptr <= 11'd0; // Reset scanner to the absolute top-left slot of VRAM
                        state    <= 3'd4;  // Jump directly to the Screen Redraw Routine
                    end else begin
                        // Standard Typing Handling
                        if (mem_din[7:0] == 8'h0D || mem_din[7:0] == 8'h0A) begin
                            mem_wr <= 1'b0; // Newlines don't print characters into VRAM
                        end else begin
                            mem_addr <= {5'b0, cursor_ptr};
                            mem_dout <= {8'h00, mem_din[7:0]};
                            mem_wr   <= 1'b1; // Pulse VRAM write immediately
                        end
                        state <= 3'd2;
                    end
                end

                3'd2: begin
                    // State 2: Pull down VRAM write strobe, calculate cursor movements, and trigger immediate echo
                    mem_wr <= 1'b0; 
                    
                    // CR/LF Processing: Snap cursor directly to Column 0 of the NEXT row down
                    if (live_key == 8'h0D || live_key == 8'h0A) begin
                        if (current_row == 5'd31)
                            cursor_ptr <= 11'd64; // Wrap completely back to start line 1
                        else
                            cursor_ptr <= (current_row + 1'b1) * 64; 
                    end else begin
                        // Advance normal character pointer position sequentially
                        if (cursor_ptr == 11'd2047)
                            cursor_ptr <= 11'd64; 
                        else
                            cursor_ptr <= cursor_ptr + 1'b1;
                    end
                    
                    // Send the captured key back out to the UART data register instantly
                    mem_addr <= 16'h8000;
                    mem_dout <= {8'h00, live_key};
                    mem_wr   <= 1'b1; // Trigger immediate single-cycle echo strobe
                    state    <= 3'd3;
                end

                3'd3: begin
                    // State 3: Turn off echo strobe and return instantly to idle polling loop
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002;
                    state    <= 3'd0;
                end

                // =========================================================
                // SCREEN REDRAW INTERRUPT ROUTINE
                // =========================================================
                3'd4: begin
                    mem_wr   <= 1'b0;
                    // Step 1: Request data byte from current VRAM scan address offset
                    mem_addr <= {5'b0, scan_ptr};
                    state    <= 3'd5;
                end

                3'd5: begin
                    // Step 2: Grab the character from memory bus and drop it straight into UART TX
                    mem_addr <= 16'h8000;
                    mem_dout <= {8'h00, mem_din[7:0]};
                    mem_wr   <= 1'b1; // Strobe the echo line to output the character byte
                    state    <= 3'd6;
                end

                3'd6: begin
                    mem_wr <= 1'b0;
                    
                    // Step 3: Check if we hit a 64-column matrix line boundary
                    if (scan_col == 6'd63) begin
                        // Send a Carriage Return down the echo line to prevent terminal text stacking
                        mem_addr <= 16'h8000;
                        mem_dout <= 16'h000D; 
                        mem_wr   <= 1'b1;
                    end
                    
                    // Advance pointer or terminate
                    if (scan_ptr == 11'd2047) begin
                        state <= 3'd0; // Scan finished! Clear state back to standard keyboard polling
                    end else begin
                        scan_ptr <= scan_ptr + 1'b1;
                        state    <= 3'd4; // Loop back up to scan next memory cell
                    end
                end

                default: state <= 3'd0;
            endcase
        end
    end
endmodule
