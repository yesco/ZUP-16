// =========================================================================
// Open-Source DVI / HDMI Transmission Module for Yosys + Tang Nano 20K
// Replaces encrypted commercial Gowin IP cores with synthesizable primitives
// =========================================================================

module hdmi_encoder_top (
    input  wire       clk_pixel,    // 27 MHz Pixel Clock
    input  wire       clk_serial,   // 135 MHz High-Speed Shift Clock (5x Pixel)
    input  wire       rst_n,        // Active Low System Reset
    input  wire [7:0] r, g, b,      // 8-bit Video Data Channels
    input  wire       hsync,        // Horizontal Sync Pulse
    input  wire       vsync,        // Vertical Sync Pulse
    input  wire       video_active, // Active High Visibility Window
    
    // Physical Output Interface Mapped by terminal.cst
    output wire       tmds_clk_p,   tmds_clk_n,
    output wire [2:0] tmds_data_p,  tmds_data_n
);

    // ---------------------------------------------------------------------
    // 1. TMDS 8b/10b Signal Encoders
    // ---------------------------------------------------------------------
    wire [9:0] tmds_r, tmds_g, tmds_b;

    // Instantiate 8b/10b converters for each fundamental channel color block
    tmds_channel_encoder enc_b (.clk(clk_pixel), .rst_n(rst_n), .vd(b), .c0(hsync), .c1(vsync), .de(video_active), .tmds(tmds_b));
    tmds_channel_encoder enc_g (.clk(clk_pixel), .rst_n(rst_n), .vd(g), .c0(1'b0),  .c1(1'b0),  .de(video_active), .tmds(tmds_g));
    tmds_channel_encoder enc_r (.clk(clk_pixel), .rst_n(rst_n), .vd(r), .c0(1'b0),  .c1(1'b0),  .de(video_active), .tmds(tmds_r));

    // ---------------------------------------------------------------------
    // 2. Hardware 10:1 Serializer Architecture Primitives (OSER10)
    // ---------------------------------------------------------------------
    wire ser_clk, ser_b, ser_g, ser_r;

    // ---------------------------------------------------------------------
    // 2. Hardware 10:1 Serializer Architecture Primitives (OSER10)
    // ---------------------------------------------------------------------
    wire ser_clk, ser_b, ser_g, ser_r;

    // Fixed: Stripped out the invalid .GSRAM parameter block for Yosys compatibility
    OSER10 ser_clk_inst (.Q(ser_clk), .D0(1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1), .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));
    OSER10 ser_b_inst   (.Q(ser_b),   .D0(tmds_b), .D1(tmds_b), .D2(tmds_b), .D3(tmds_b), .D4(tmds_b), .D5(tmds_b), .D6(tmds_b), .D7(tmds_b), .D8(tmds_b), .D9(tmds_b), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));
    OSER10 ser_g_inst   (.Q(ser_g),   .D0(tmds_g), .D1(tmds_g), .D2(tmds_g), .D3(tmds_g), .D4(tmds_g), .D5(tmds_g), .D6(tmds_g), .D7(tmds_g), .D8(tmds_g), .D9(tmds_g), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));
    OSER10 ser_r_inst   (.Q(ser_r),   .D0(tmds_r), .D1(tmds_r), .D2(tmds_r), .D3(tmds_r), .D4(tmds_r), .D5(tmds_r), .D6(tmds_r), .D7(tmds_r), .D8(tmds_r), .D9(tmds_r), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));

    // Use Gowin's native OSER10 blocks to step parallel 10-bit words out to 1-bit streams
//    OSER10 #(.GSRAM("FALSE")) ser_clk_inst (.Q(ser_clk), .D0(1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1), .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));
//    OSER10 #(.GSRAM("FALSE")) ser_b_inst   (.Q(ser_b),   .D0(tmds_b[0]), .D1(tmds_b[1]), .D2(tmds_b[2]), .D3(tmds_b[3]), .D4(tmds_b[4]), .D5(tmds_b[5]), .D6(tmds_b[6]), .D7(tmds_b[7]), .D8(tmds_b[8]), .D9(tmds_b[9]), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));
//    OSER10 #(.GSRAM("FALSE")) ser_g_inst   (.Q(ser_g),   .D0(tmds_g[0]), .D1(tmds_g[1]), .D2(tmds_g[2]), .D3(tmds_g[3]), .D4(tmds_g[4]), .D5(tmds_g[5]), .D6(tmds_g[6]), .D7(tmds_g[7]), .D8(tmds_g[8]), .D9(tmds_g[9]), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));
//    OSER10 #(.GSRAM("FALSE")) ser_r_inst   (.Q(ser_r),   .D0(tmds_r[0]), .D1(tmds_r[1]), .D2(tmds_r[2]), .D3(tmds_r[3]), .D4(tmds_r[4]), .D5(tmds_r[5]), .D6(tmds_r[6]), .D7(tmds_r[7]), .D8(tmds_r[8]), .D9(tmds_r[9]), .PCLK(clk_pixel), .FCLK(clk_serial), .RESET(!rst_n));

    // ---------------------------------------------------------------------
    // 3. Hardware True Differential Drivers (ELVDS_OBUF)
    // ---------------------------------------------------------------------
    // Drive single-ended serialized bits out to physical differential pin pairs [2.3.3, 2.4'C]
    ELVDS_OBUF drv_clk (.O(tmds_clk_p), .OB(tmds_clk_n), .I(ser_clk));
    ELVDS_OBUF drv_b   (.O(tmds_data_p[0]), .OB(tmds_data_n[0]), .I(ser_b));
    ELVDS_OBUF drv_g   (.O(tmds_data_p[1]), .OB(tmds_data_n[1]), .I(ser_g));
    ELVDS_OBUF drv_r   (.O(tmds_data_p[2]), .OB(tmds_data_n[2]), .I(ser_r));

endmodule

// Standard 8b/10b TMDS Encoder Sub-Module logic
module tmds_channel_encoder (
    input  wire       clk, rst_n,
    input  wire [7:0] vd,
    input  wire       c0, c1, de,
    output reg  [9:0] tmds
);
    reg [3:0] cnt;
    wire [3:0] ones = vd[0]+vd[1]+vd[2]+vd[3]+vd[4]+vd[5]+vd[6]+vd[7];
    wire xn = (ones > 4) || (ones == 4 && !vd[0]);
    wire [8:0] q_m = xn ? {1'b0, ~(q_m[0]^vd[1]), ~(q_m[1]^vd[2]), ~(q_m[2]^vd[3]), ~(q_m[3]^vd[4]), ~(q_m[4]^vd[5]), ~(q_m[5]^vd[6]), ~(q_m[6]^vd[7]), vd[0]} :
                          {1'b1,   (q_m[0]^vd[1]),   (q_m[1]^vd[2]),   (q_m[2]^vd[3]),   (q_m[3]^vd[4]),   (q_m[4]^vd[5]),   (q_m[5]^vd[6]),   (q_m[6]^vd[7]), vd[0]};
    wire [3:0] q_m_ones = q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tmds <= 10'b0; cnt <= 4'b0;
        end else if (!de) begin
            cnt <= 4'b0;
            case ({c1, c0})
                2'b00:   tmds <= 10'b1101010100;
                2'b01:   tmds <= 10'b0010101011;
                2'b10:   tmds <= 10'b0101010100;
                default: tmds <= 10'b1010101011;
            endcase
        end else begin
            if (cnt == 0 || q_m_ones == 4) begin
                tmds <= {~q_m[8], q_m[8], q_m[7:0] ^ {8{~q_m[8]}}};
                cnt  <= q_m[8] ? cnt + (q_m_ones - 4) : cnt + (4 - q_m_ones);
            end else if ((!cnt[3] && q_m_ones > 4) || (cnt[3] && q_m_ones < 4)) begin
                tmds <= {1'b1, q_m[8], q_m[7:0] ^ 8'hFF};
                cnt  <= cnt + {q_m[8], 1'b0} + (4 - q_m_ones);
            end else begin
                tmds <= {1'b0, q_m[8], q_m[7:0]};
                cnt  <= cnt - {~q_m[8], 1'b0} + (q_m_ones - 4);
            end
        end
    end
endmodule
