// =========================================================================
// Universal Mock CPU Engine (Synchronized Bus Interface)
// Fixes data window sampling race conditions and pulse width timing bugs
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
    reg [7:0]  captured_key;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr     <= 16'h8002; // Boot directly pointing to UART status
            mem_dout     <= 16'h0000;
            mem_wr       <= 1'b0;
            state        <= 3'd0;
            cursor_ptr   <= 11'd64;   // Row 1, Col 0 (Leaves header title safe)
            captured_key <= 8'h00;
        end else begin
            case (state)
                3'd0: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002; // Keep monitoring UART Status Register
                    
                    // IF Bit 0 (rx_data_valid) is high, the data on 0x8000 is ready RIGHT NOW.
                    // Instead of waiting, we change addresses to 0x8000 immediately to capture it 
                    // on the next rising edge before the UART module clears it.
                    if (mem_din[0] == 1'b1) begin 
                        mem_addr <= 16'h8000; 
                        state    <= 3'd1;
                    end
                end

                3'd1: begin
                    // State 1: Instantly sample the data lines to lock the character byte in registers
                    captured_key <= mem_din[7:0];
                    mem_wr       <= 1'b0;
                    state        <= 3'd2;
                end

                3'd2: begin
                    // State 2: Issue a SINGLE-CYCLE write pulse to text VRAM
                    mem_addr <= {5'b0, cursor_ptr};
                    mem_dout <= {8'h00, captured_key};
                    mem_wr   <= 1'b1; // Trigger strobe pulse up
                    state    <= 3'd3;
                end

                3'd3: begin
                    // State 3: Turn OFF VRAM write strobe immediately, advance tracking index safely
                    mem_wr   <= 1'b0; // Pull strobe down to exactly 1 clock cycle width
                    
                    if (cursor_ptr == 11'd2047)
                        cursor_ptr <= 11'd64; 
                    else
                        cursor_ptr <= cursor_ptr + 1'b1;
                        
                    state    <= 3'd4;
                end

                3'd4: begin
                    // State 4: Check if UART TX is free, then pulse a SINGLE-CYCLE echo command
                    mem_addr <= 16'h8002; // Look at status
                    if (mem_din[1] == 1'b0) begin // If Bit 1 (tx_data_busy) is LOW, TX is completely idle
                        mem_addr <= 16'h8000; // Point to data slot
                        mem_dout <= {8'h00, captured_key};
                        mem_wr   <= 1'b1;  // Raise TX trigger pulse up
                        state    <= 3'd5;
                    end
                end

                3'd5: begin
                    // State 5: Instantly pull down the TX strobe to prevent duplicates, return to idle
                    mem_wr   <= 1'b0; // Strobe low
                    mem_addr <= 16'h8002;
                    state    <= 3'd0;
                end

                default: state <= 3'd0;
            endcase
        end
    end
endmodule
