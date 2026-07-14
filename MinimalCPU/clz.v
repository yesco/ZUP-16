// ====================================================================
// Pure Logarithmic CLZ Module
// ====================================================================
// Gowin synthesis directive to force lean LUT mapping

// Should be 10-15 LUT, and maybe 64 2MUX (cells)

(* gowin_attributes = "loop_to_lut" *) 
module clz (
    input  wire [15:0] in,       // 16-bit input number
    output wire [4:0]  clz_out   // 5-bit output (Values from 0 to 16)
);

    // --- LEVEL 1: Check upper 8 bits ---
    wire       zero_8  = (in[15:8] == 8'b0);
    wire [7:0] stage1  = zero_8 ? in[7:0] : in[15:8];

    // --- LEVEL 2: Check upper 4 bits ---
    wire       zero_4  = (stage1[7:4] == 4'b0);
    wire [3:0] stage2  = zero_4 ? stage1[3:0] : stage1[7:4];

    // --- LEVEL 3: Check upper 2 bits ---
    wire       zero_2  = (stage2[3:2] == 2'b0);
    wire [1:0] stage3  = zero_2 ? stage2[1:0] : stage2[3:2];

    // --- LEVEL 4: Check the final top bit ---
    wire       zero_1  = (stage3[1] == 1'b0);

    // --- SPECIAL CASE: Input is completely 0 ---
    wire       all_zero = zero_1 && (stage3[0] == 1'b0);

    // --- COMBINE THE SCENT ---
    assign clz_out[4] = all_zero;
    assign clz_out[3] = !all_zero && zero_8;
    assign clz_out[2] = !all_zero && zero_4;
    assign clz_out[1] = !all_zero && zero_2;
    assign clz_out[0] = !all_zero && zero_1;

endmodule

// ====================================================================
// Top-Level Module for Tang Nano 20K Hardware Test
// ====================================================================
module top (
    input  wire [15:0] sw,      // Map to 16 external switches/pins
    output wire [5:0]  led      // Connects to the 6 onboard LEDs
);

    wire [4:0] count;

    // Instantiate your CLZ module
    clz u_clz (
        .in(sw),
        .clz_out(count)
    );

    // Physical Interface Mapping:
    // 1. The Tang Nano 20K has 6 onboard LEDs (led[5:0]) which are active-low.
    // 2. We invert the 5-bit count (~count) so that a binary '1' lights up an LED.
    // 3. We keep led[5] turned off (1'b1) as a power indicator or padding.
    assign led[4:0] = ~count;
    assign led[5]   = 1'b1; 

endmodule
