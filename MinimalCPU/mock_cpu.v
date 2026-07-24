// =========================================================================
// Universal Mock CPU Engine (Immediate Single-Cycle Pass-Through)
// Fixed: Eliminates the 1-character pipeline typing registration lag
// =========================================================================

module mock_terminal_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [15:0] mem_addr,
    output reg  [15:0] mem_dout,
    input  wire [15:0] mem_din,
    output reg         mem_wr
);
    reg [1:0]  state;
    reg [10:0] cursor_ptr;
    reg [7:0]  live_key;

    // Helper wires to breakdown cursor positioning (64 columns per row)
    wire [4:0] current_row = cursor_ptr / 64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr    <= 16'h8002; // Monitor UART Status Register
            mem_dout    <= 16'h0000;
            mem_wr      <= 1'b0;
            state       <= 2'd0;
            cursor_ptr  <= 11'd64;   // Starts on Row 1, Col 0
            live_key    <= 8'h00;
        end else begin
            case (state)
                2'd0: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002; 
                    
                    // If Bit 0 (rx_data_valid) is high, jump instantly to read the character
                    if (mem_din == 1'b1) begin 
                        mem_addr <= 16'h8000; 
                        state    <= 2'd1;
                    end
                end

                2'd1: begin
                    // State 1: Capture the live key from the data bus
                    live_key <= mem_din[7:0];
                    
                    // Handle write address immediately based on whether it is a newline or standard key
                    if (mem_din[7:0] == 8'h0D || mem_din[7:0] == 8'h0A) begin
                        mem_wr   <= 1'b0; // Newlines don't print a visible character into VRAM matrix
                    end else begin
                        mem_addr <= {5'b0, cursor_ptr};
                        mem_dout <= {8'h00, mem_din[7:0]};
                        mem_wr   <= 1'b1; // Pulse VRAM write immediately
                    end
                    state <= 2'd2;
                end

                2'd2: begin
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
                    state    <= 2'd3;
                end

                2'd3: begin
                    // State 3: Turn off echo strobe and return instantly to idle polling loop
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002;
                    state    <= 2'd0;
                end

                default: state <= 2'd0;
            endcase
        end
    end
endmodule
