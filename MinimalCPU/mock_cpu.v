// =========================================================================
// Universal Mock CPU Engine (Synchronized Bus Interface)
// Fixed: Handles Carriage Returns (\r) and Line Feeds (\n) inside Raw Mode
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

    // Helper wires to breakdown cursor positioning (64 columns per row)
    wire [4:0] current_row = cursor_ptr / 64;
    wire [5:0] current_col = cursor_ptr % 64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr     <= 16'h8002; 
            mem_dout     <= 16'h0000;
            mem_wr       <= 1'b0;
            state        <= 3'd0;
            cursor_ptr   <= 11'd64;   // Starts on Row 1, Col 0
            captured_key <= 8'h00;
        end else begin
            case (state)
                3'd0: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002; 
                    if (mem_din == 1'b1) begin 
                        mem_addr <= 16'h8000; 
                        state    <= 3'd1;
                    end
                end

                3'd1: begin
                    captured_key <= mem_din[7:0];
                    mem_wr       <= 1'b0;
                    state        <= 3'd2;
                end

                3'd2: begin
                    // Handle Carriage Return or Line Feed
                    if (captured_key == 8'h0D || captured_key == 8'h0A) begin
                        mem_wr <= 1'b0; // No character visible to print inside VRAM matrix
                        state  <= 3'd3;
                    end else begin
                        // Print standard alphanumeric character to visible matrix cell
                        mem_addr <= {5'b0, cursor_ptr};
                        mem_dout <= {8'h00, captured_key};
                        mem_wr   <= 1'b1; 
                        state    <= 3'd3;
                    end
                end

                3'd3: begin
                    mem_wr <= 1'b0; 
                    
                    // CR/LF Processing: Drop to Column 0 of the NEXT row down
                    if (captured_key == 8'h0D || captured_key == 8'h0A) begin
                        if (current_row == 5'd31)
                            cursor_ptr <= 11'd64; // Wrap completely back to start line 1
                        else
                            cursor_ptr <= (current_row + 1'b1) * 64; // Force step index forward to col 0
                    end else begin
                        // Advance index pointer normally
                        if (cursor_ptr == 11'd2047)
                            cursor_ptr <= 11'd64; 
                        else
                            cursor_ptr <= cursor_ptr + 1'b1;
                    end
                        
                    state <= 3'd4;
                end

                3'd4: begin
                    mem_addr <= 16'h8002; 
                    if (mem_din == 1'b0) begin 
                        mem_addr <= 16'h8000; 
                        
                        // Output Patch: Expand simple line entries to clean terminal parameters
                        if (captured_key == 8'h0D || captured_key == 8'h0A) begin
                            // Echo BOTH characters (\r\n) back out to the Unix console to fix the staircase
                            mem_dout <= 16'h000A; // Inject the missing LF
                        end else begin
                            mem_dout <= {8'h00, captured_key};
                        end
                        
                        mem_wr   <= 1'b1;  
                        state    <= 3'd5;
                    end
                end

                3'd5: begin
                    mem_wr   <= 1'b0; 
                    mem_addr <= 16'h8002;
                    state    <= 3'd0;
                end

                default: state <= 3'd0;
            endcase
        end
    end
endmodule
