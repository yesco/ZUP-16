// =========================================================================
// Universal Mock CPU Engine (Handshaking Verification Architecture)
// Fixed: Eliminates typing lag, double keystrokes, and Ctrl+L stalls
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
    
    reg [10:0] scan_ptr;
    wire [5:0] scan_col = scan_ptr % 64;
    wire [4:0] current_row = cursor_ptr / 64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr    <= 16'h8002;
            mem_dout    <= 16'h0000;
            mem_wr      <= 1'b0;
            state       <= 3'd0;
            cursor_ptr  <= 11'd64;   // Row 1, Col 0
            live_key    <= 8'h00;
            scan_ptr    <= 11'd0;
        end else begin
            case (state)
                3'd0: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002; 
                    
                    // If a valid key arrives, grab it immediately
                    if (mem_din == 1'b1) begin 
                        mem_addr <= 16'h8000; 
                        state    <= 3'd1;
                    end
                end

                3'd1: begin
                    live_key <= mem_din[7:0];
                    mem_wr   <= 1'b0;
                    
                    if (mem_din[7:0] == 8'h0C) begin // Ctrl+L Intercept
                        scan_ptr <= 11'd0;
                        state    <= 3'd4; 
                    end else begin
                        if (mem_din[7:0] == 8'h0D || mem_din[7:0] == 8'h0A) begin
                            mem_wr <= 1'b0;
                        end else begin
                            mem_addr <= {5'b0, cursor_ptr};
                            mem_dout <= {8'h00, mem_din[7:0]};
                            mem_wr   <= 1'b1;
                        end
                        state <= 3'd2;
                    end
                end

                3'd2: begin
                    mem_wr <= 1'b0; 
                    if (live_key == 8'h0D || live_key == 8'h0A) begin
                        if (current_row == 5'd31)
                            cursor_ptr <= 11'd64;
                        else
                            cursor_ptr <= (current_row + 1'b1) * 64; 
                    end else begin
                        if (cursor_ptr == 11'd2047) cursor_ptr <= 11'd64;
                        else cursor_ptr <= cursor_ptr + 1'b1;
                    end
                    
                    mem_addr <= 16'h8000;
                    mem_dout <= {8'h00, live_key};
                    mem_wr   <= 1'b1; 
                    state    <= 3'd3;
                end

                3'd3: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002;
                    // HANDSHAKE SAFETY: Wait right here until the testbench lowering 
                    // of the valid flag registers on the bus. This stops double-typing.
                    if (mem_din == 1'b0) begin
                        state <= 3'd0;
                    end
                end

                // --- Ctrl+L Screen Dump ---
                3'd4: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= {5'b0, scan_ptr};
                    state    <= 3'd5;
                end

                3'd5: begin
                    mem_addr <= 16'h8000;
                    mem_dout <= {8'h00, mem_din[7:0]};
                    mem_wr   <= 1'b1;
                    state    <= 3'd6;
                end

                3'd6: begin
                    mem_wr <= 1'b0;
                    if (scan_col == 6'd63) begin
                        mem_addr <= 16'h8000;
                        mem_dout <= 16'h000D; 
                        mem_wr   <= 1'b1;
                    end
                    
                    if (scan_ptr == 11'd2047) begin
                        state <= 3'd3; // Head to the safe handshake exit state
                    end else begin
                        scan_ptr <= scan_ptr + 1'b1;
                        state    <= 3'd4;
                    end
                end

                default: state <= 3'd0;
            endcase
        end
    end
endmodule
