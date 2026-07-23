module j1_cpu_core (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [15:0] mem_addr,
    output reg  [15:0] mem_dout,
    input  wire [15:0] mem_din,
    output reg         mem_wr
);
    reg [1:0]  state;
    reg [10:0] simulated_cursor;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr         <= 16'h0000;
            mem_dout         <= 16'h0000;
            mem_wr           <= 1'b0;
            state            <= 2'd0;
            simulated_cursor <= 11'd64; // Initialize at offset 64 (Row 1, Column 0) to leave header intact
        end else begin
            case (state)
                2'd0: begin
                    mem_addr <= 16'h8002; // Poll UART Status
                    mem_wr   <= 1'b0;
                    if (mem_din == 1'b1) begin // character ready flag caught
                        mem_addr <= 16'h8000; // Issue read command
                        state    <= 2'd1;
                    end
                end
                
                2'd1: begin
                    // Write the key directly to the screen at next sequential memory cell location
                    mem_addr <= {5'b0, simulated_cursor};
                    mem_dout <= {8'h00, mem_din[7:0]};
                    mem_wr   <= 1'b1;
                    
                    // Increment cell pointer index, prevent tracking overflow beyond screen array limits
                    if (simulated_cursor == 11'd2047)
                        simulated_cursor <= 11'd64; // Simple screen wrap loopback bypasses header line
                    else
                        simulated_cursor <= simulated_cursor + 1'b1;
                        
                    state    <= 2'd2;
                end

                2'd2: begin
                    // Echo character directly back out the UART TX port line
                    mem_addr <= 16'h8000;
                    mem_dout <= mem_dout; 
                    mem_wr   <= 1'b1;
                    state    <= 2'd3;
                end
                
                2'd3: begin
                    mem_wr <= 1'b0;
                    state  <= 2'd0;
                end
            endcase
        end
    end
endmodule
