// =========================================================================
// Gowin Hardware Phase-Locked Loop Architecture Primitive (rPLL)
// Verified parameter map for Open-Source Yosys + Tang Nano 20K Targets
// =========================================================================

module gowin_rpll (
    output wire clkout, // Primary Accelerated Output: 135.000 MHz
    input  wire clkin   // Source Crystal Input:     27.000 MHz
);

    wire gw_gnd;
    assign gw_gnd = 1'b0;

    // Structural Instantiation using ONLY verified open-source Yosys primitives
    rPLL #(
        .FCLKIN("27"),
        .IDIV_SEL(0),
        .FBDIV_SEL(4),       // Multiply Input by 5 (27 MHz * 5 = 135 MHz)
        .ODIV_SEL(4),
        .PSDA_SEL("0000"),
        .DUTYDA_SEL("1000")
    ) rpll_internal_inst (
        .CLKOUT(clkout),
        .CLKIN(clkin),
        .CLKFB(gw_gnd),
        .RESET(gw_gnd),
        .RESET_P(gw_gnd)
    );

endmodule
