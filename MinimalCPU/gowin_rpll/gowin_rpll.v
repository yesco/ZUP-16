// =========================================================================
// Gowin Hardware Phase-Locked Loop Architecture Primitive (rPLL)
// Configures a direct 5x Multiplication Step: 27 MHz -> 135 MHz
// =========================================================================

module gowin_rpll (
    output wire clkout, // Primary Accelerated Output: 135.000 MHz
    input  wire clkin   // Reference Crystal Input:     27.000 MHz
);

    wire clkoutd_unused;
    wire clkoutd3_unused;
    wire gw_gnd;
    assign gw_gnd = 1'b0;

    // Direct instantiation of the physical Gowin silicon hard-macro cell
    rPLL #(
        .FCLKIN("27"),
        .IDIV_SEL(0),
        .FBDIV_SEL(4), // Multiply Clock Source factor by 5 (Fout = Fin * 5 / 1)
        .ODIV_SEL(4),
        .PSDA_SEL("0000"),
        .DUTYDA_SEL("1000"),
        .CLKOUTD_SRC("CLKOUT"),
        .CLKOUTD_DIV(2)
    ) rpll_internal_inst (
        .CLKOUT(clkout),
        .CLKOUTD(clkoutd_unused),
        .CLKOUTD3(clkoutd3_unused),
        .CLKIN(clkin),
        .CLKFB(gw_gnd),
        .RESET(gw_gnd),
        .RESET_P(gw_gnd),
        .INSEL(gw_gnd),
        .IDSEL(3'b000),
        .FDSEL(6'b000000),
        .PSDA(4'b0000),
        .DUTYDA(4'b0000)
    );

endmodule
