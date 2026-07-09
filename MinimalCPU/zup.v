// ZUP.v - Byte-coded 16-bit dual-stack machine
//
// SYSTEM RULES:
// 1. Do NOT change lines unless really needed for goatl.
// 2. If have inconsistent goal, STOP and explain, DON'T make changes.
// 3. Keep formatting and structure as much as possible.

`define WORD [W-1:0]

module zup #(
    parameter W = 16
)(
    input  wire [7:0] op, // Full 8-bit instruction token
    input  wire `WORD t,  // Current Top of Stack (Live/Bypassed)
    input  wire `WORD n,  // Current Next on Stack (Live/Bypassed)
    input  wire `WORD r,  // Current Return Stack Top (Live/Bypassed)
    input  wire `WORD pc, // Current pc
    input  wire       c,  // Live Carry input flag
    
    output reg  `WORD T,  // New Top of Stack out
    output reg  `WORD N,  // New Next on Stack out
    output reg        C,  // New Carry output flag
    output reg  [1:0] sd, // Data Stack Pointer Delta (0, 1, -1)
    output reg  [1:0] rd, // Return Stack Pointer Delta (0, 1, -1)
    output reg  `WORD PC  // Next State Program Counter Value out
);

    wire `WORD zeroes = { W{1'b0} };
    wire `WORD ones   = { W{1'b1} };

    wire is_op = op;
    wire [4:0] key = op[4:0];

    reg  `WORD a, b;
    reg        cin;
    wire [W:0] sum = a + b + cin;
    wire [2*W-1:0] mul = n * t;

    always @(*) begin
        // Baseline global hardware defaults
        T= t; N= n; C= 0; sd= 0; rd= 0; a= n; b= t; cin= 0; PC= pc;
 
        if (!is_op) begin // Cheaper with if!
            T= op; sd= 1; // Literal flag processing
        end else begin
            casez (op) // Cheaper with full opo (-20 LUT)!
                // --- GROUP 0: Two-Argument Reductions (224-231) ---
                8'b11100000: begin sd=-1; {C,T}= sum; a= n; b= t; cin=0; end // add
                8'b11100001: begin sd=-1; {C,T}= sum; a= n; b= t; cin=c; end // adc
                8'b11100010: begin sd=-1; {C,T}= sum; a= n; b=~t; cin=1; end // sub
                8'b11100011: begin sd=-1;     T= t;                      end // nip
                8'b11100100: begin sd=-1;     T= n & t;                  end // and
                8'b11100101: begin sd=-1;     T= n | t;                  end // or
                8'b11100110: begin sd=-1;     T= n ^ t;                  end // xor
                8'b11100111: begin sd=-1;     T= n;                      end // drop
          
                // --- GROUP 1: Control Flow & Inversions (232-239) ---
                8'b11101000: begin     T=~t;                       end // not
                8'b11101001: begin {C,T}= sum; a= 0; b=~t; cin= 1; end // neg
                8'b11101010: begin     T= t;                       end // nop
                8'b11101011: begin     T= n;                       end // swap
                8'b11101100: begin     T= n;                       end // rot
                8'b11101101: begin sd=-1; if(!n) PC= t;            end // zjp
                8'b11101110: begin sd=-1; if(!c) PC= t;            end // njp
                8'b11101111: begin rd=-1;                          end // ret

                // --- GROUP 2: Math Modifiers and Shifters (240-247) ---
                8'b11110000: begin {C,T}= sum; a= 0;    b= t; cin= 1; end // inc
                8'b11110001: begin {C,T}= sum; a= ones; b= t; cin= 0; end // dec
                8'b11110010: begin {T,C}= {   t[W-1],    t };         end // asr
                8'b11110011: begin {T,C}= { t, t[W-1:1], t };         end // ror
                8'b11110100: begin {T,C}= { 1'b0,        t };         end // shr1
                8'b11110101: begin {C,T}= sum; a= t;    b= t; cin= 0; end // shl1
                8'b11110110: begin     T= { 4'b0000,t[W-1:4] }; C= t; end // shr4
                8'b11110111: begin     T= { t[W-5:0],4'b0000 }; C= t; end // shl4

                // --- GROUP 3: Stack Mutation & Return Stack Hooks (248-255) ---
                8'b11111000: begin           {T,N}= mul;                   end // mul
                8'b11111001: begin sd=-1; rd= 1; T= n;                     end // >r
                8'b11111010: begin sd= 1;        T= r;                     end // @r
                8'b11111011: begin sd= 1; rd=-1; T= r;                     end // r>
                8'b11111100: begin sd= 1;        T= t;                     end // tuck
                8'b11111101: begin sd= 1;        T= n;                     end // over
                8'b11111110: begin sd= 1;        T= t;                     end // dup
                8'b11111111: begin sd= 1;        T= ones;                  end // true
            endcase
        end
    end

endmodule
