// =========================================================================
// Pure Behavioral Open-Source DVI Transmitter Engine for Yosys
// Updated with explicit TLVDS_OBUF hardware macros to satisfy gowin_pack
// =========================================================================

module hdmi_encoder_top (
    input  wire       clk_pixel,    // 27 MHz Pixel Clock
    input  wire       clk_serial,   // 135 MHz High-Speed Clock (5x Pixel)
    input  wire       rst_n,        // Active Low Reset
    input  wire [7:0] r, g, b,      // Video Data Channels
    input  wire       hsync,        // Horizontal Sync Pulse
    input  wire       vsync,        // Vertical Sync Pulse
    input  wire       video_active, // Active High Display Window
    
    // Physical Output Interface Mapped by terminal.cst
    output wire       tmds_clk_p,   tmds_clk_n,
    output wire [2:0] tmds_data_p,  tmds_data_n
);

    // ---------------------------------------------------------------------
    // 1. TMDS 8b/10b Signal Encoders
    // ---------------------------------------------------------------------
    wire [9:0] tmds_r, tmds_g, tmds_b;

    tmds_channel_encoder enc_b (.clk(clk_pixel), .rst_n(rst_n), .vd(b), .c0(hsync), .c1(vsync), .de(video_active), .tmds(tmds_b));
    tmds_channel_encoder enc_g (.clk(clk_pixel), .rst_n(rst_n), .vd(g), .c0(1'b0),  .c1(1'b0),  .de(video_active), .tmds(tmds_g));
    tmds_channel_encoder enc_r (.clk(clk_pixel), .rst_n(rst_n), .vd(r), .c0(1'b0),  .c1(1'b0),  .de(video_active), .tmds(tmds_r));

    // ---------------------------------------------------------------------
    // 2. Behavioral Serialization
    // ---------------------------------------------------------------------
    reg [9:0] shift_r, shift_g, shift_b;
    reg [9:0] shift_clk;
    reg [3:0] bit_cnt;

    always @(posedge clk_serial or negedge rst_n) begin
        if (!rst_n) begin
            shift_r   <= 10'b0;
            shift_g   <= 10'b0;
            shift_b   <= 10'b0;
            shift_clk <= 10'b11111_00000; // 50% Duty cycle clock signature
            bit_cnt   <= 4'd0;
        end else begin
            if (bit_cnt == 4'd9) begin
                bit_cnt   <= 4'd0;
                shift_r   <= tmds_r;
                shift_g   <= tmds_g;
                shift_b   <= tmds_b;
                shift_clk <= 10'b11111_00000;
            end else begin
                bit_cnt   <= bit_cnt + 1'b1;
                shift_r   <= shift_r   >> 1;
                shift_g   <= shift_g   >> 1;
                shift_b   <= shift_b   >> 1;
                shift_clk <= shift_clk >> 1;
            end
        end
    end

    // ---------------------------------------------------------------------
    // 3. Hardware True Differential Drivers (TLVDS_OBUF Primitives)
    // Instantiating these explicitly prevents Yosys/nextpnr from using OBUFs
    // ---------------------------------------------------------------------
    wire ser_clk_out = shift_clk[0];
    wire ser_b_out   = shift_b[0];
    wire ser_g_out   = shift_g[0];
    wire ser_r_out   = shift_r[0];

    TLVDS_OBUF drv_clk  (.O(tmds_clk_p),     .OB(tmds_clk_n),     .I(ser_clk_out));
    TLVDS_OBUF drv_chan0(.O(tmds_data_p[0]), .OB(tmds_data_n[0]), .I(ser_b_out)); // Blue / Syncs
    TLVDS_OBUF drv_chan1(.O(tmds_data_p[1]), .OB(tmds_data_n[1]), .I(ser_g_out)); // Green
    TLVDS_OBUF drv_chan2(.O(tmds_data_p[2]), .OB(tmds_data_n[2]), .I(ser_r_out)); // Red

endmodule

// Standard 8b/10b TMDS Encoder Module
module tmds_channel_encoder (
    input  wire       clk, rst_n,
    input  wire [7:0] vd,
    input  wire       c0, c1, de,
    output reg  [9:0] tmds
);
    reg [3:0] cnt;
    wire [3:0] ones = vd[0]+vd[1]+vd[2]+vd[3]+vd[4]+vd[5]+vd[6]+vd[7];
    wire xn = (ones > 4) || (ones == 4 && !vd[0]);
    wire [8:0] q_m;
    
    assign q_m[0] = vd[0];
    assign q_m[1] = xn ? ~(q_m[0]^vd[1]) : (q_m[0]^vd[1]);
    assign q_m[2] = xn ? ~(q_m[1]^vd[2]) : (q_m[1]^vd[2]);
    assign q_m[3] = xn ? ~(q_m[2]^vd[3]) : (q_m[2]^vd[3]);
    assign q_m[4] = xn ? ~(q_m[3]^vd[4]) : (q_m[3]^vd[4]);
    assign q_m[5] = xn ? ~(q_m[4]^vd[5]) : (q_m[4]^vd[5]);
    assign q_m[6] = xn ? ~(q_m[5]^vd[6]) : (q_m[5]^vd[6]);
    assign q_m[7] = xn ? ~(q_m[6]^vd[7]) : (q_m[6]^vd[7]);
    assign q_m[8] = xn ? 1'b0 : 1'b1;

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
            </case>
        end else begin
            if (cnt == 0 || q_m_ones == 4) begin
                tmds[9]   <= ~q_m[8];
                tmds[8]   <= q_m[8];
                tmds[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
                cnt       <= q_m[8] ? cnt + (q_m_ones - 4) : cnt + (4 - q_m_ones);
            end else if ((!cnt && q_m_ones > 4) || (cnt && q_m_ones < 4)) begin
                tmds[9]   <= 1'b1;
                tmds[8]   <= q_m[8];
                tmds[7:0] <= ~q_m[7:0];
                cnt       <= cnt + {q_m[8], 1'b0} + (4 - q_m_ones);
            end else begin
                tmds[9]   <= 1'b0;
                tmds[8]   <= q_m[8];
                tmds[7:0] <= q_m[7:0];
                cnt       <= cnt - {~q_m[8], 1'b0} + (q_m_ones - 4);
            end
        end
    end
endmodule
