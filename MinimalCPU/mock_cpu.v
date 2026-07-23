// =========================================================================
// Universal Mock CPU Engine (Standard Bus Interface Wrapper)
// Operates at 27 MHz - Directly implements typing & echo behavior
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
    reg [7:0]  captured_key;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr     <= 16'h0000;
            mem_dout     <= 16'h0000;
            mem_wr       <= 1'b0;
            state        <= 2'd0;
            cursor_ptr   <= 11'd64;  // Start exactly on Row 1, Column 0 (leaves title intact)
            captured_key <= 8'h00;
        end else begin
            case (state)
                2'd0: begin
                    mem_wr   <= 1'b0;
                    mem_addr <= 16'h8002; // Poll UART Status Register
                    if (mem_din[0] == 1'b1) begin // Check bit 0: rx_data_valid
                        mem_addr <= 16'h8000; // Step to read data register
                        state    <= 2'd1;
                    end
                end

                2'd1: begin
                    // Read data phase: grab key and schedule VRAM write operation
                    captured_key <= mem_din[7:0];
                    mem_addr     <= {5'b0, cursor_ptr};
                    mem_dout     <= {8'h00, mem_din[7:0]};
                    mem_wr       <= 1'b1;
                    
                    // Increment position and loop back before hitting end of VRAM
                    if (cursor_ptr == 11'd2047)
                        cursor_ptr <= 11'd64; 
                    else
                        cursor_ptr <= cursor_ptr + 1'b1;

                    state        <= 2'd2;
                end

                2'd2: begin
                    // Write to serial data register to trigger the physical TX echo loop
                    mem_addr <= 16'h8000;
                    mem_dout <= {8'h00, captured_key};
                    mem_wr   <= 1'b1;
                    state    <= 2'd3;
                end

                2'd3: begin
                    // Clear pipeline strobe signals and head back to status polling
                    mem_wr <= 1'b0;
                    state  <= 2'd0;
                end
            endcase
        end
    end
endmodule
