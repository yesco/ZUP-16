// =========================================================================
// Simulation Mocks for Tang Nano 20K Terminal Subsystems
// Save as mocks.v to satisfy Icarus Verilog compilation dependencies
// =========================================================================

// 1. Mock Gowin rPLL Module
module gowin_rpll (
    output reg clkout,
    input  wire clkin
);
    initial clkout = 1'b0;
    // Simulate a 5x clock multiplication (27 MHz -> 135 MHz)
    // 27MHz period is ~37ns (18.5ns half). 135MHz period is ~7.4ns (3.7ns half).
    always begin
        #3.704 clkout = ~clkout;
    end
endmodule


// 2. Mock J1 CPU Core Engine (Simulates an echo loopback program)
// Reads from UART data address (0x8000) when ready, writes to Text VRAM (0x0000)
module j1_cpu_core (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [15:0] mem_addr,
    output reg  [15:0] mem_dout,
    input  wire [15:0] mem_din,
    output reg         mem_wr
);
    reg [2:0] state;
    reg [10:0] simulated_cursor;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr  <= 16'h0000;
            mem_dout  <= 16'h0000;
            mem_wr    <= 1'b0;
            state     <= 3'd0;
            simulated_cursor <= 11'd0;
        end else begin
            case (state)
                0: begin // Poll UART status register (0x8002)
                    mem_addr <= 16'h8002;
                    mem_wr   <= 1'b0;
                    state    <= 3'd1;
                end
                1: begin // Check if RX data ready flag (bit 0) is set
                    if (mem_din[0] == 1'b1) begin
                        mem_addr <= 16'h8000; // Switch to read UART Data
                        state    <= 3'd2;
                    end else begin
                        state    <= 3'd0; // Keep polling
                    end
                end
                2: begin // Capture data and prepare to write to text matrix VRAM
                    mem_addr <= {5'b0, simulated_cursor};
                    mem_dout <= mem_din; // Echo character data byte
                    mem_wr   <= 1'b1;
                    state    <= 3'd3;
                end
                3: begin // Complete VRAM layout write
                    mem_wr   <= 1'b0;
                    simulated_cursor <= simulated_cursor + 1'b1;
                    state    <= 3'd0;
                end
                default: state <= 3'd0;
            endcase
        end
    end
endmodule


// 3. Mock Video Timing Generator (Standard 640x480 resolution arrays)
module video_timing_generator (
    input  wire       clk_pix,
    input  wire       rst_n,
    output reg  [9:0] out_x,
    output reg  [9:0] out_y,
    output reg        out_active,
    output reg        out_hsync,
    output reg        out_vsync
);
    // Simple VGA counter architecture constants
    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            out_x <= 10'd0;
            out_y <= 10'd0;
        end else begin
            if (out_x == 10'd799) begin
                out_x <= 10'd0;
                if (out_y == 10'd524) begin
                    out_y <= 10'd0;
                end else begin
                    out_y <= out_y + 1'b1;
                end
            end else begin
                out_x <= out_x + 1'b1;
            end
        end
    end

    // Formulate display visibility bounding box logic
    always @(*) begin
        out_active = (out_x < 640) && (out_y < 480);
        out_hsync  = ~(out_x >= 656 && out_x < 752); // Standard Sync Pulses
        out_vsync  = ~(out_y >= 490 && out_y < 492);
    end
endmodule


// 4. Mock Font Look-Up Table Array ROM (Provides simple geometric lines for testing)
module font_rom_8x16 (
    input  wire [7:0] char_code,
    input  wire [3:0] row_index,
    output reg  [7:0] line_data
);
    always @(*) begin
        // Returns a checker pattern for printable text, blanking space variations
        if (char_code == 8'h00 || char_code == 8'h20)
            line_data = 8'h00; 
        else
            line_data = (row_index[0]) ? 8'hAA : 8'h55; // Visible pixel hash lines
    end
endmodule


// 5. Mock DVI / HDMI Transmission Matrix Encoder
module hdmi_encoder_top (
    input  wire       clk_pixel,
    input  wire       clk_serial,
    input  wire       rst_n,
    input  wire [7:0] r, g, b,
    input  wire       hsync,
    input  wire       vsync,
    input  wire       video_active,
    output reg  [2:0] tmds_clk_p,  tmds_clk_n,
    output reg  [2:0] tmds_data_p, tmds_data_n
);
    // Suppress unreferenced clock wire warnings inside compilation run
    wire dummy = clk_pixel ^ clk_serial;
    
    always @(posedge clk_serial or negedge rst_n) begin
        if (!rst_n) begin
            tmds_clk_p  <= 3'b101; tmds_clk_n  <= 3'b010;
            tmds_data_p <= 3'b000; tmds_data_n <= 3'b111;
        end else begin
            // Stub toggles to indicate data transmission activity
            tmds_data_p <= {video_active, hsync, vsync};
            tmds_data_n <= ~{video_active, hsync, vsync};
        end
    end
endmodule
