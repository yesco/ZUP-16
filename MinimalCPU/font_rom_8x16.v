// =========================================================================
// Full Alphanumeric 128-Character Font Table ROM Engine
// Hardware Architecture Strategy: Targets 2048 Matrix Bytes on Tang Nano 20K
// =========================================================================

module font_rom_8x16 (
    input  wire [7:0] char_code,  // ASCII character code
    input  wire [3:0] row_index,  // 0 to 15 vertical line scan index inside cell
    output reg  [7:0] line_data   // 8 horizontal parallel pixels out
);

    // Array definition depth: 128 characters * 16 rows = 2048 rows total
    reg [7:0] font_mem [0:2047];

    initial begin
        // The hardware compiler reads the raw hex values directly here!
        $readmemh("vga_font_16.hex", font_mem);
    end

    // Map elements explicitly via unified block addressing
    always @(*) begin
        if (char_code < 8'd128) begin
            line_data = font_mem[{char_code[6:0], row_index}];
        end else begin
            line_data = 8'h00; // Return empty black space for high-bit characters
        end
    end

endmodule
