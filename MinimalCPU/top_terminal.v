// =========================================================================
// Tang Nano 20K - One True Master Top Module (CLI Optimized)
// Assumes a generic `CPU defined to an actual; if unset uses a mock.
// Modular UART, Dual-Port Video Matrix, and HDMI TX
// Features: Hardcoded "Yesco Terminal TN20K" Header on Line 0
// =========================================================================

module top_terminal (
    input  wire       sys_clk,     // Physical Crystal Input (27 MHz)
    input  wire       sys_rst_n,   // Physical Reset Button (Active Low)
    input  wire       uart_rx,     // RX Input Pin from BL616 MCU
    output wire       uart_tx,     // TX Output Pin to BL616 MCU
    
    // Physical Differential Pin Pairs mapped by terminal_pins.cst
    output wire [2:0] tmds_clk_p,  tmds_clk_n,
    output wire [2:0] tmds_data_p, tmds_data_n
);

    // ---------------------------------------------------------------------
    // 1. Clock Generation Framework
    // ---------------------------------------------------------------------
    wire clk_pix;   // 27 MHz Pixel Clock
    wire clk_serial;// 135 MHz Phase Clock (5x Pixel clock for TMDS)

    gowin_rpll my_pll_inst (
        .clkout(clk_serial), 
        .clkin(sys_clk)      
    );
    
    assign clk_pix = sys_clk; 

    // ---------------------------------------------------------------------
    // 2. Inter-Module Interconnect System Lines
    // ---------------------------------------------------------------------
    wire [15:0] cpu_mem_addr;
    wire [15:0] cpu_mem_dout;
    reg  [15:0] cpu_mem_din;
    wire        cpu_mem_wr;
    
    wire [7:0]  uart_rx_byte;
    wire        uart_rx_ready;
    reg         uart_tx_enqueue;
    wire        uart_tx_ready;
    wire        uart_tx_busy;
    
    // Text Framebuffer Video Matrix (Shared Memory Map)
    // 64 Columns * 32 Rows Matrix = 2048 Characters total Block RAM allocation
    reg  [7:0]  text_vram [0:2047]; 
    wire [10:0] cpu_vram_addr = cpu_mem_addr[10:0];
    wire [10:0] video_vram_addr;
    wire [7:0]  video_active_char;

    wire is_vram_space = (cpu_mem_addr >= 16'h0000 && cpu_mem_addr <= 16'h07FF);
    wire is_uart_data  = (cpu_mem_addr == 16'h8000);
    wire is_uart_stat  = (cpu_mem_addr == 16'h8002);

    // ---------------------------------------------------------------------
    // Initial Memory Setup: Hardcode "Yesco Terminal TN20K" into Line 0
    // ---------------------------------------------------------------------
    integer idx;
    initial begin
        // Clear all terminal buffer spaces to standard blank character (ASCII 0x20)
        for (idx = 0; idx < 2048; idx = idx + 1) begin
            text_vram[idx] = 8'h20; 
        end
        // Inline Title String Insertion at Line 0 indices (0 to 19)
        text_vram[0]  = 8'h59; // Y
        text_vram[1]  = 8'h65; // e
        text_vram[2]  = 8'h73; // s
        text_vram[3]  = 8'h63; // c
        text_vram[4]  = 8'h6F; // o
        text_vram[5]  = 8'h20; // [Space]
        text_vram[6]  = 8'h54; // T
        text_vram[7]  = 8'h65; // e
        text_vram[8]  = 8'h72; // r
        text_vram[9]  = 8'h6D; // m
        text_vram[10] = 8'h69; // i
        text_vram[11] = 8'h6E; // n
        text_vram[12] = 8'h61; // a
        text_vram[13] = 8'h6C; // l
        text_vram[14] = 8'h20; // [Space]
        text_vram[15] = 8'h54; // T
        text_vram[16] = 8'h4E; // N
        text_vram[17] = 8'h32; // 2
        text_vram[18] = 8'h30; // 0
        text_vram[19] = 8'h4B; // K
    end

    // ---------------------------------------------------------------------
    // 3. Hot-Swappable CPU Interconnect Bus
    // ---------------------------------------------------------------------
    // The main infrastructure doesn't care what is plugged in here, 
    // as long as it exposes the standard memory-mapped interface wires.
    
    `ifdef CPU
        // Your real custom CPU architecture target
        `CPU cpu (
            .clk(clk_pix),
            .rst_n(sys_rst_n),
            .mem_addr(cpu_mem_addr),
            .mem_dout(cpu_mem_dout),
            .mem_din(cpu_mem_din),
            .mem_wr(cpu_mem_wr)
        );
    `else
        // Default Fallback: Automated Test Mock CPU Engine
        mock_terminal_cpu cpu (
            .clk(clk_pix),
            .rst_n(sys_rst_n),
            .mem_addr(cpu_mem_addr),
            .mem_dout(cpu_mem_dout),
            .mem_din(cpu_mem_din),
            .mem_wr(cpu_mem_wr)
        );
    `endif

    always @(*) begin
        if (is_vram_space)
            cpu_mem_din = {8'h00, text_vram[cpu_vram_addr]};
        else if (is_uart_data)
            cpu_mem_din = {8'h00, uart_rx_byte};
        else if (is_uart_stat)
            cpu_mem_din = {14'b0, uart_tx_busy, uart_rx_ready};
        else
            cpu_mem_din = 16'h0000;
    end

    always @(posedge clk_pix) begin
        if (cpu_mem_wr) begin
            if (is_vram_space) begin
                text_vram[cpu_vram_addr] <= cpu_mem_dout[7:0];
            end
            if (is_uart_data) begin
                uart_tx_enqueue <= 1'b1;
            end
        end else begin
            uart_tx_enqueue <= 1'b0;
        end
    end

    // ---------------------------------------------------------------------
    // 4. Reusable Dual-Wire UART Block
    // ---------------------------------------------------------------------
    wire rx_data_ready_wire = 1'b1; 
    
    uart_rx #(
        .CLK_FRE(27),          
        .BAUD_RATE(115200)
    ) my_uart_receiver (
        .clk(clk_pix),
        .rst_n(sys_rst_n),
        .rx_data(uart_rx_byte),
        .rx_data_valid(uart_rx_ready),
        .rx_data_ready(rx_data_ready_wire), 
        .rx_pin(uart_rx)
    );

    uart_tx #(
        .CLK_FRE(27),          
        .BAUD_RATE(115200)
    ) my_uart_transmitter (
        .clk(clk_pix),
        .rst_n(sys_rst_n),
        .tx_data(cpu_mem_dout[7:0]),
        .tx_data_valid(uart_tx_enqueue),
        .tx_data_ready(uart_tx_ready), 
        .tx_pin(uart_tx)
    );

    assign uart_tx_busy = ~uart_tx_ready;

    // ---------------------------------------------------------------------
    // 5. Video Rendering Engine & Character ROM Grid
    // ---------------------------------------------------------------------
    wire [9:0] pixel_x, pixel_y;
    wire       video_blank_n; 
    wire       hsync_sig, vsync_sig;

    video_timing_generator my_sync_gen (
        .clk_pix(clk_pix),
        .rst_n(sys_rst_n),
        .out_x(pixel_x),
        .out_y(pixel_y),
        .out_active(video_blank_n),
        .out_hsync(hsync_sig),
        .out_vsync(vsync_sig)
    );

    wire [5:0] text_col = pixel_x[9:3]; // Div 8
    wire [4:0] text_row = pixel_y[9:4]; // Div 16
    assign video_vram_addr = {text_row, text_col};
    
    assign video_active_char = text_vram[video_vram_addr];

    wire [7:0] font_row_bits;
    font_rom_8x16 internal_font_table (
        .char_code(video_active_char),
        .row_index(pixel_y[3:0]),
        .line_data(font_row_bits)
    );

    wire active_pixel = font_row_bits[3'd7 - pixel_x[2:0]];

    wire [7:0] channel_r = 8'h00;
    wire [7:0] channel_g = (video_blank_n && active_pixel) ? 8'hFF : 8'h00;
    wire [7:0] channel_b = 8'h00;

    // ---------------------------------------------------------------------
    // 6. HDMI Transmitter Serializer Interface
    // ---------------------------------------------------------------------
    hdmi_encoder_top my_hdmi (
        .clk_pixel(clk_pix),
        .clk_serial(clk_serial),
        .rst_n(sys_rst_n),
        .r(channel_r), .g(channel_g), .b(channel_b),
        .hsync(hsync_sig), .vsync(vsync_sig),
        .video_active(video_blank_n),
        .tmds_clk_p(tmds_clk_p),   .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p), .tmds_data_n(tmds_data_n)
    );

endmodule
