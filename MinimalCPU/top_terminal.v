// =========================================================================
// Tang Nano 20K - One True Master Top Module (Hardware Synthesizable)
// Features: Synchronous BRAM optimization while preserving CPU macro logic
// =========================================================================

module top_terminal (
    input  wire       sys_clk,     // Physical Crystal Input (27 MHz)
    input  wire       sys_rst_n,   // Physical Reset Button (Active Low)
    input  wire       uart_rx,     // RX Input Pin from BL616 MCU
    output wire       uart_tx,     // TX Output Pin to BL616 MCU
    
    // Physical Differential Output Pins
    output wire       tmds_clk_p,  tmds_clk_n,
    output wire [2:0] tmds_data_p, tmds_data_n
);

    // ---------------------------------------------------------------------
    // 1. Clock Generation Framework (Simulation and Hardware Aware)
    // ---------------------------------------------------------------------
    wire clk_pix;   // 27 MHz Pixel Clock
    wire clk_serial;// 135 MHz Phase Clock (5x Pixel clock for TMDS)

    assign clk_pix = sys_clk; 

    `ifdef SIMULATION
        // In simulation, we short-circuit high-speed clocks to prevent hangs
        assign clk_serial = sys_clk; 
    `else
        // Hardware Target: Instantiate physical rPLL primitive for Tang Nano 20K
        gowin_rpll my_pll_inst (
            .clkout(clk_serial), 
            .clkin(sys_clk)      
        );
    `endif

    // ---------------------------------------------------------------------
    // 2. Inter-Module Interconnect System Lines
    // ---------------------------------------------------------------------
    wire [15:0] cpu_mem_addr;
    wire [15:0] cpu_mem_dout;
    reg  [15:0] cpu_mem_din;
    wire        cpu_mem_wr;
    
    wire [7:0]  uart_rx_byte;
    wire        uart_rx_ready;
    wire        uart_tx_enqueue;
    wire        uart_tx_ready;
    wire        uart_tx_busy;
    
    // True Dual-Port Synchronous Block RAM Framework
    reg  [7:0]  text_vram [0:2047]; 
    wire [10:0] cpu_vram_addr = cpu_mem_addr[10:0];
    wire [10:0] video_vram_addr;
    reg  [7:0]  video_active_char; // Registered BRAM out cell to stop LUT inflation

    wire is_vram_space = (cpu_mem_addr >= 16'h0000 && cpu_mem_addr <= 16'h07FF);
    wire is_uart_data  = (cpu_mem_addr == 16'h8000);
    wire is_uart_stat  = (cpu_mem_addr == 16'h8002);

    // ---------------------------------------------------------------------
    // Initial Memory Setup: Hardcode "Yesco Terminal TN20K" into Line 0
    // ---------------------------------------------------------------------
    integer idx;
    initial begin
        for (idx = 0; idx < 2048; idx = idx + 1) begin
            text_vram[idx] = 8'h20; // Default blank space character
        end
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

    // Port A: Synchronous RAM Write Channel
    always @(posedge clk_pix) begin
        if (cpu_mem_wr && is_vram_space) begin
            text_vram[cpu_vram_addr] <= cpu_mem_dout[7:0];
        end
    end

    // Port B: Synchronous RAM Read Channel for Video Engine (Infers Block RAM)
    always @(posedge clk_pix) begin
        video_active_char <= text_vram[video_vram_addr];
    end

    // ---------------------------------------------------------------------
    // 3. Hot-Swappable CPU Interconnect Bus (Preserved CPU Logic)
    // ---------------------------------------------------------------------
    `ifdef CPU
        // Instantiates whatever core name is defined to the CPU macro variable
        `CPU target_cpu (
            .clk(clk_pix),
            .rst_n(sys_rst_n),
            .mem_addr(cpu_mem_addr),
            .mem_dout(cpu_mem_dout),
            .mem_din(cpu_mem_din),
            .mem_wr(cpu_mem_wr)
        );
    `else
        // Fallback default mock engine
        mock_terminal_cpu target_cpu (
            .clk(clk_pix),
            .rst_n(sys_rst_n),
            .mem_addr(cpu_mem_addr),
            .mem_dout(cpu_mem_dout),
            .mem_din(cpu_mem_din),
            .mem_wr(cpu_mem_wr)
        );
    `endif

    // Memory Bus Multiplexer Read Routing
    always @(*) begin
        if (is_vram_space)
            cpu_mem_din = {16'h0000}; // Blocked during synchronous dual-port line assignments
        else if (is_uart_data)
            cpu_mem_din = {8'h00, uart_rx_byte};
        else if (is_uart_stat)
            cpu_mem_din = {14'b0, uart_tx_busy, uart_rx_ready};
        else
            cpu_mem_din = 16'h0000;
    end

    // Synchronize CPU transmit enqueue signal width
    assign uart_tx_enqueue = (cpu_mem_wr && is_uart_data);

    // ---------------------------------------------------------------------
    // 4. Reusable Dual-Wire UART Block (Mapped to your exact modules)
    // ---------------------------------------------------------------------
    `ifdef SIMULATION
        assign uart_rx_byte   = top_terminal_tb.sim_direct_char;
        assign uart_rx_ready  = top_terminal_tb.sim_direct_valid;
        assign uart_tx_busy   = 1'b0;
        
        always @(posedge clk_pix) begin
            if (cpu_mem_wr && is_uart_data) begin
                top_terminal_tb.trigger_instant_echo(cpu_mem_dout[7:0]);
            end
        end
    `else
        wire rx_data_ready_wire = 1'b1; 
        uart_rx #(
            .CLK_FRE(27), .BAUD_RATE(115200)
        ) my_uart_receiver (
            .clk(clk_pix), .rst_n(sys_rst_n),
            .rx_data(uart_rx_byte), .rx_data_valid(uart_rx_ready),
            .rx_data_ready(rx_data_ready_wire), .rx_pin(uart_rx)
        );

        uart_tx #(
            .CLK_FRE(27), .BAUD_RATE(115200)
        ) my_uart_transmitter (
            .clk(clk_pix), .rst_n(sys_rst_n),
            .tx_data(cpu_mem_dout[7:0]), .tx_data_valid(uart_tx_enqueue),
            .tx_data_ready(uart_tx_ready), .tx_pin(uart_tx)
        );

        assign uart_tx_busy = ~uart_tx_ready;
    `endif

    // ---------------------------------------------------------------------
    // 5. Video Rendering Engine & Character ROM Grid
    // ---------------------------------------------------------------------
    wire [9:0] pixel_x, pixel_y;
    wire       video_blank_n; 
    wire       hsync_sig, vsync_sig;

    video_timing_generator my_sync_gen (
        .clk_pix(clk_pix), .rst_n(sys_rst_n),
        .out_x(pixel_x), .out_y(pixel_y), .out_active(video_blank_n),
        .out_hsync(hsync_sig), .out_vsync(vsync_sig)
    );

    wire [5:0] text_col = pixel_x[9:3]; // Div 8
    wire [4:0] text_row = pixel_y[9:4]; // Div 16
    assign video_vram_addr = {text_row, text_col};
    
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
    // 6. HDMI Transmitter Serializer Interface (Open-Source DVI Core)
    // ---------------------------------------------------------------------
    hdmi_encoder_top my_hdmi (
        .clk_pixel(clk_pix), .clk_serial(clk_serial), .rst_n(sys_rst_n),
        .r(channel_r), .g(channel_g), .b(channel_b),
        .hsync(hsync_sig), .vsync(vsync_sig), .video_active(video_blank_n),
        .tmds_clk_p(tmds_clk_p),   .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p), .tmds_data_n(tmds_data_n)
    );

endmodule
