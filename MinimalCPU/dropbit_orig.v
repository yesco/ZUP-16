`define WORD [W-1:0]

module dropbit_orig #(
    parameter W = 8
)(

    // Current register states (Inputs)
    input  wire `WORD tos,
    input  wire `WORD nos,
    input  wire `WORD n2,
    input  wire `WORD bram_refill_val, // Automatic input port from BRAM read
    
    // Control lines
    input  wire [2:0]  opcode,          // 00:NOP/DROP, 01:DUP/SWAP, 10:TUCK/OVER, 11:ROT/NIP
    input  wire        drop_bit,        // Orthogonal modifier bit
    
    // Next register states (Outputs)
    output reg  `WORD next_tos,
    output reg  `WORD next_nos,
    output reg  `WORD next_n2,
    output reg  `WORD bram_spill_val,  // Data line routed directly to BRAM write input
    output reg  [1:0]  sd               // Signed Stack Delta (2'b11=-1, 2'b00=0, 2'b01=+1)
);

    // Two's complement signed constants for Stack Delta
    localparam SIGNED_HOLD = 2'b00; //  0
    localparam SIGNED_PUSH = 2'b01; // +1
    localparam SIGNED_DROP = 2'b11; // -1

    always @(*) begin
        // -------------------------------------------------------------
        // Hardwired Structural Defaults
        // -------------------------------------------------------------
        next_tos       = tos;
        next_nos       = nos;
        next_n2        = n2;
        bram_spill_val = n2;         // Whenever a push happens, N2 naturally spills out
        sd             = SIGNED_HOLD;

        case (opcode)
            // =========================================================
            // 1. NOP / DROP DUALITY
            // =========================================================
            3'b000: begin
                if (drop_bit) begin
                    // DROP: Everything shifts left. Bottom refilled from BRAM.
                    next_tos = nos;
                    next_nos = n2;
                    next_n2  = bram_refill_val;
                    sd       = SIGNED_DROP;
                end else begin
                    // NOP: Keeps defaults (Hold)
                end
            end

            // =========================================================
            // 2. DUP / SWAP DUALITY
            // =========================================================
            3'b001: begin
// not verified
                if (drop_bit) begin
                    // SWAP: TOS and NOS exchange places. Net depth change is zero.
                    next_tos = nos;
                    next_nos = tos;
                end else begin
                    // DUP: TOS stays. New value pushed into NOS. Old NOS falls to N2.
                    next_nos = tos;
                    next_n2  = nos;
                    sd       = SIGNED_PUSH; // Triggers BRAM write of old N2
                end
            end

            // =========================================================
            // 3. TUCK / OVER DUALITY (Polar Opposites)
            // =========================================================
            3'b010: begin
// WRONG!
                if (drop_bit) begin
                    // OVER: TOS gets a copy of NOS. Stack drops to balance depth.
                    next_tos = nos;
                    next_nos = n2;
                    next_n2  = bram_refill_val;
                    sd       = SIGNED_DROP;
// WRONG!
                end else begin
                    // TUCK: NOS gets TOS. Old NOS slides down to N2.
                    next_nos = tos;
                    next_n2  = nos;
                    sd       = SIGNED_PUSH; // Triggers BRAM write of old N2
                end
            end

            // =========================================================
            // 4. ROT / NIP DUALITY
            // =========================================================
            3'b011: begin
                if (drop_bit) begin
                    // NIP: TOS is untouched. NOS is bypassed and filled from below.
                    next_nos = n2;
                    next_n2  = bram_refill_val;
                    sd       = SIGNED_DROP;
                end else begin
                    // ROT: Pure 3-element fabric shuffle. Depth change is zero.
                    next_tos = nos;
                    next_nos = n2;
                    next_n2  = tos;
                end
            end

            // =========================================================
            // 100: THE ADDITION OPERATION (+)
            // =========================================================
            3'b100: begin
                // Both Keep and Drop variants perform the exact same math into next_tos
                next_tos = tos + nos;

                if (drop_bit) begin
                    next_nos = n2;
                    next_n2  = bram_spill_val2;
                end
            end

        endcase
    end

endmodule
