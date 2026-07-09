// This experiment is look at benefit of a VLIW "dropbit"

`define WORD [W-1:0]

module dropbit #(
		  parameter W = 8
		 )(

		    input wire	     `WORD tos,
		    input wire	     `WORD nos,
		    input wire	     `WORD n2,
		    input wire	     `WORD bram_refill_val,

		    input wire	     drop_bit,
		    input wire [2:0] opcode, // Expanded to 3 bits to fit the ALU operations

		    output reg	     `WORD next_tos,
		    output reg	     `WORD next_nos,
		    output reg	     `WORD next_n2,
		    output reg [1:0] sd	// Stack Delta: 2'b11=-1, 2'b00=0, 2'b01=+1
		   );

   localparam SIGNED_HOLD = 2'b00; //  0
   localparam SIGNED_PUSH = 2'b01; // +1
   localparam SIGNED_DROP = 2'b11; // -1

   always @(*) begin
      // -------------------------------------------------------------
      // NEW HIGH-EFFICIENCY DEFAULTS (The "Natural" Stack Flow)
      // -------------------------------------------------------------
      // default: assumed drop (... n2 nos tos - ... n2 nos)
      next_tos = nos;               // Default: Everything shifts UP into TOS
      next_nos = n2;                // Default: Everything shifts UP into NOS
      next_n2  = bram_refill_val;   // Default: Bottom fills from BRAM
      sd       = drop_bit ? SIGNED_DROP : SIGNED_HOLD; // Default Stack Delta

      case (opcode)
        // =========================================================
        // 000: NOP / DROP DUALITY
        // =========================================================
        3'b000: begin
           if (!drop_bit) begin // (n2 nos tos - n2 nos tos)
              // NOP override: Override the defaults to FREEZE all data
              next_tos = tos;
              next_nos = nos;
              next_n2  = n2;
           end
	   // else: (n2 nos tos - n2 nos)
	   
           // If drop_bit is 1 (DROP), we write ZERO lines of code! 
           // The global defaults already perform a perfect DROP.
        end

        // =========================================================
        // 001: DUP / SWAP DUALITY
        // =========================================================
        3'b001: begin
          if (drop_bit) begin // (n2 nos tos - n2 tos nos)
              // SWAP: Override next_nos to catch the old TOS
              next_nos = tos;
              next_n2  = nos;
              sd       = SIGNED_HOLD; // Net stack depth change is zero
           end else begin // (n2 nos tos - n2 nos tos tos)
              // DUP: TOS stays put, NOS gets TOS, N2 gets old NOS
              next_tos = tos;
              next_nos = tos;
              next_n2  = nos;
              sd       = SIGNED_PUSH;
           end
        end

        // =========================================================
        // 010: TUCK / OVER DUALITY
        // 010: THE PROPAGATION PAIR (Polar Reverses)
        // =========================================================
        3'b010: begin
           sd      = SIGNED_PUSH; // BOTH variants push data down to BRAM

           if (drop_bit) begin  // (... n2 nos tos - ... n2 tos nos tos)
              // TUCK: TOS stays put, NOS gets a copy of TOS
              next_tos = tos;
              next_nos = nos;
	      next_n2  = tos;
           end else begin  // (... n2 nos tos - ... n2 nos tos nos)
              // OVER: TOS gets a copy of NOS, NOS gets the old TOS
              next_tos = nos; // Reduntandt
              next_nos = tos;
	      next_n2  = nos;
           end
        end

        // =========================================================
        // 011: ROT / NIP DUALITY
        // =========================================================
        3'b011: begin
           if (drop_bit) begin // (... n2 nos tos - n2 tos)
              // NIP: TOS freezes, NOS and N2 pull from below
              next_tos = tos;
           end else begin // (n2 nos tos - tos n2 nos)
              // ROT: Pure 3-element fabric shuffle
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

           if (!drop_bit) begin // (n2 nos tos - n2 nos tos+nos)
              // Keep Mode (+keep): Freeze NOS and N2 underneath the new sum
              next_nos = nos;
              next_n2  = n2;
           end
           // else: (n2 nos tos - n2 tos+nos)
           // If drop_bit is 1 (+drop): The global defaults automatically 
           // pull n2 up to nos, pull BRAM up to n2, and issue a SIGNED_DROP!
        end

        default: begin
           // Catch-all for unallocated ALU opcodes
           next_tos = tos;
           next_nos = nos;
           next_n2  = n2;
        end
      endcase
   end

endmodule
