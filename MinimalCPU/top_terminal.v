// =========================================================================
// Tang Nano 20K - One True Master Top Module (CLI Optimized)
// Integrates J1 CPU Core, Modular UART, Dual-Port Video Matrix, and HDMI TX
// =========================================================================

module top_terminal (
    input  wire       sys_clk,     // Physical Crystal Input (27 MHz)
    input  wire       sys_rst_n,   // Physical Reset Button (Active Low)
    input  wire       uart_rx,     // RX Input Pin from BL616 MCU
    output wire       uart_tx,     // TX Output Pin to BL616 MCU
    
    // Physical Differential Pin Pairs mapped by terminal_pins.cst [2.4'C]
    output wire [2:0] tmds_clk_p,  tmds_clk_n,
    output wire [2:0] tmds_data_p, tmds_data_n
);

    // ---------------------------------------------------------------------
    // 1. Clock Generation Framework
    // ---------------------------------------------------------------------
    wire clk_pix;   // 27 MHz Pixel Clock
    wire clk_serial;// 135 MHz Phase Clock (5x Pixel clock for TMDS)

    // Instantiate your imported rPLL block from gowin_rpll/gowin_rpll.v
    gowin_rpll my_pll_inst (
        .clkout(clk_serial), // Multiplied 5x Clock output
        .clkin(sys_clk)      // 27 MHz System Crystal reference input
    );
    
    assign clk_pix = sys_clk; // Direct 27 MHz clock bypass matches 640x480 video timings

    // ---------------------------------------------------------------------
    // 2. Inter-Module Interconnect System Lines
    // ---------------------------------------------------------------------
    // CPU System Bus Lines
    wire [15:0] cpu_mem_addr;
    wire [15:0] cpu_mem_dout;
    reg  [15:0] cpu_mem_din;
    wire        cpu_mem_wr;
    
    // UART Subsystem Lines
    wire [7:0]  uart_rx_byte;
    wire        uart_rx_ready;
    reg         uart_tx_enqueue;
    wire	uart_tx_busy;

    
    // Text Framebuffer Video Matrix (Shared Memory Map)
    // 64 Columns * 32 Rows Matrix = 2048 Characters total Block RAM allocation
    reg  [7:0]  text_vram [0:2047]; 
    wire [10:0] cpu_vram_addr = cpu_mem_addr[10:0];
    wire [10:0] video_vram_addr;
    wire [7:0]  video_active_char;

    // Memory-Mapped IO Decoding Condition Definitions
    wire is_vram_space = (cpu_mem_addr >= 16'h0000 && cpu_mem_addr <= 16'h07FF);
    wire is_uart_data  = (cpu_mem_addr == 16'h8000);
    wire is_uart_stat  = (cpu_mem_addr == 16'h8002);

    // ---------------------------------------------------------------------
    // 3. J1 Minimialist CPU Core Execution Block
    // ---------------------------------------------------------------------
    // Stripped down wrapper tracking from j1_top.v
    j1_cpu_core my_cpu (
        .clk(clk_pix),
        .rst_n(sys_rst_n),
        .mem_addr(cpu_mem_addr),
        .mem_dout(cpu_mem_dout),
        .mem_din(cpu_mem_din),
        .mem_wr(cpu_mem_wr)
    );

    // Memory-Read Routing Engine Multiplexer
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

    // Memory-Write Decoding Block (CPU Output Driving Logic)
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
    // 4. Reusable Dual-Wire UART Block (Mapped to Sipeed Naming Structure)
    // ---------------------------------------------------------------------
    // Maps standard Sipeed example code structures cleanly to the system bus

    // ---------------------------------------------------------------------
    // 4. Reusable Dual-Wire UART Block (Mapped directly to your exact modules)
    // ---------------------------------------------------------------------
    
    // Wire to tell the receiver we are always ready to accept incoming characters
    wire rx_data_ready_wire = 1'b1; 
    
    uart_rx #(
        .CLK_FRE(27),          // Tang Nano 20K native clock speed
        .BAUD_RATE(115200)
    ) my_uart_receiver (
        .clk(clk_pix),
        .rst_n(sys_rst_n),
        .rx_data(uart_rx_byte),
        .rx_data_valid(uart_rx_ready),
        .rx_data_ready(rx_data_ready_wire), // Must be driven high to accept data
        .rx_pin(uart_rx)
    );

    wire uart_tx_ready_from_mod;

    uart_tx #(
        .CLK_FRE(27),          // Tang Nano 20K native clock speed
        .BAUD_RATE(115200)
    ) my_uart_transmitter (
        .clk(clk_pix),
        .rst_n(sys_rst_n),
        .tx_data(cpu_mem_dout[7:0]),
        .tx_data_valid(uart_tx_enqueue),
        .tx_data_ready(uart_tx_ready_from_mod), // High means IDLE / READY to send
        .tx_pin(uart_tx)
    );

    // Invert the module's "ready" signal to drive our system bus "busy" status net
    assign uart_tx_busy = ~uart_tx_ready_from_mod;



    // ---------------------------------------------------------------------
    // 5. Video Rendering Engine & Character ROM Grid
    // ---------------------------------------------------------------------
    wire [9:0] pixel_x, pixel_y;
    wire       video_blank_n; // Active High outside HSync/VSync blank window
    wire       hsync_sig, vsync_sig;

    // Generates core video sync array parameters
    video_timing_generator my_sync_gen (
        .clk_pix(clk_pix),
        .rst_n(sys_rst_n),
        .out_x(pixel_x),
        .out_y(pixel_y),
        .out_active(video_blank_n),
        .out_hsync(hsync_sig),
        .out_vsync(vsync_sig)
    );

    // Read Character coordinates: Font cell width = 8 pixels, height = 16 pixels
    wire [5:0] text_col = pixel_x[9:3]; // Div 8
    wire [4:0] text_row = pixel_y[9:4]; // Div 16
    assign video_vram_addr = {text_row, text_col};
    
    // Concurrent Second-Port Async Reading from VRAM Block to Screen
    assign video_active_char = text_vram[video_vram_addr];

    // Character Matrix Line Bit Extractor
    wire [7:0] font_row_bits;
    font_rom_8x16 internal_font_table (
        .char_code(video_active_char),
        .row_index(pixel_y[3:0]),
        .line_data(font_row_bits)
    );

    // Select target single column pixel state from the extracted row byte
    wire active_pixel = font_row_bits[3'd7 - pixel_x[2:0]];

    // Matrix Terminal Color Mapping (Active Matrix Bits = Bright Green tint)
    wire [7:0] channel_r = 8'h00;
    wire [7:0] channel_g = (video_blank_n && active_pixel) ? 8'hFF : 8'h00;
    wire [7:0] channel_b = 8'h00;

    // ---------------------------------------------------------------------
    // 6. HDMI Transmitter Serializer Interface
    // ---------------------------------------------------------------------
    // Clean interface integration mapped straight out of dvi_tx/ files [2.4'C]
    hdmi_encoder_top my_hdmi (
        .clk_pixel(clk_pix),
        .clk_serial(clk_serial),
        .rst_n(sys_rst_n),
        .r(channel_r), 
        .g(channel_g), 
        .b(channel_b),
        .hsync(hsync_sig), 
        .vsync(vsync_sig),
        .video_active(video_blank_n),
        .tmds_clk_p(tmds_clk_p),   .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p), .tmds_data_n(tmds_data_n)
    );

endmodule
