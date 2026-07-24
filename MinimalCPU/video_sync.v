// =========================================================================
// Standard 640x480 @ 60Hz Video Synchronization Generator
// =========================================================================

module video_timing_generator (
    input  wire       clk_pix,   // 27 MHz Clock
    input  wire       rst_n,
    output reg  [9:0] out_x,
    output reg  [9:0] out_y,
    output reg        out_active,
    output reg        out_hsync,
    output reg        out_vsync
);
    // Line & Frame structural tracking boundaries
    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            out_x <= 10'd0; out_y <= 10'd0;
        end else begin
            if (out_x == 10'd799) begin
                out_x <= 10'd0;
                if (out_y == 10'd524) out_y <= 10'd0;
                else out_y <= out_y + 1'b1;
            end else out_x <= out_x + 1'b1;
        end
    end

    // Signal state asserts
    always @(*) begin
        out_active = (out_x < 640) && (out_y < 480);
        out_hsync  = !(out_x >= 656 && out_x < 752); // Standard HSync pulse logic
        out_vsync  = !(out_y >= 490 && out_y < 492); // Standard VSync pulse logic
    end
endmodule
