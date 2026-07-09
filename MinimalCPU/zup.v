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
    input wire [7:0]   op, // Full 8-bit instruction token
    input wire [W-1:0] t,  // Current Top of Stack (Live/Bypassed)
    input wire [W-1:0] n,  // Current Next on Stack (Live/Bypassed)
    input wire [W-1:0] r,  // Current Return Stack Top (Live/Bypassed)
    input wire [W-1:0] pc, // Current pc
    input wire	       c,  // Live Carry input flag
    
    output reg [W-1:0] T,  // New Top of Stack out
    output reg [W-1:0] N,  // New Carry output flag
    output reg	       C,  // New Carry output flag
    output reg [1:0]   sd, // Data Stack Pointer Delta (0, 1, -1)
    output reg [1:0]   rd, // Return Stack Pointer Delta (0, 1, -1)
    output reg [W-1:0] PC  // Next State Program Counter Value out
);

    wire [W-1:0] zeroes = { W{1'b0} };
    wire [W-1:0] ones   = { W{1'b1} };

    wire is_op = op;
    wire [4:0] key = op[4:0];

    reg  [W-1:0] a, b;
    reg          cin;
    wire [W:0]   sum = a + b + cin;
    wire [2*W-1:0] mul = n * t;

    always @(*) begin
        // Baseline global hardware defaults
        T= t; N= n; C= 0; sd= 0; rd= 0; a= n; b= t; cin= 0; PC= pc;
 
        if (!is_op) begin
            T= op; sd= 1; // Literal flag processing
        end else begin
            case (key)
                // --- GROUP 0: Two-Argument Reductions (224-231) ---
                5'b00000: begin sd=-1; {C,T}= sum; a= n; b= t; cin=0; end // add
                5'b00001: begin sd=-1; {C,T}= sum; a= n; b= t; cin=c; end // adc
                5'b00010: begin sd=-1; {C,T}= sum; a= n; b=~t; cin=1; end // sub
                5'b00011: begin sd=-1;     T= t;                      end // nip
                5'b00100: begin sd=-1;     T= n & t;                  end // and
                5'b00101: begin sd=-1;     T= n | t;                  end // or
                5'b00110: begin sd=-1;     T= n ^ t;                  end // xor
                5'b00111: begin sd=-1;     T= n;                      end // drop
          
                // --- GROUP 1: Control Flow & Inversions (232-239) ---
                5'b01000: begin     T=~t;                       end // not
                5'b01001: begin {C,T}= sum; a= 0; b=~t; cin= 1; end // neg
                5'b01010: begin     T= t;                       end // nop
                5'b01011: begin     T= n;                       end // swap
                5'b01100: begin     T= n;                       end // rot
                5'b01101: begin sd=-1; if(!n) PC= t;            end // zjp
                5'b01110: begin sd=-1; if(!c) PC= t;            end // njp
                5'b01111: begin rd=-1;                          end // ret

                // --- GROUP 2: Math Modifiers and Shifters (240-247) ---
                5'b10000: begin {C,T}= sum; a= 0;    b= t; cin= 1; end // inc
                5'b10001: begin {C,T}= sum; a= ones; b= t; cin= 0; end // dec
                5'b10010: begin {T,C}= {   t[W-1],    t };         end // asr
                5'b10011: begin {T,C}= { t, t[W-1:1], t };         end // ror
                5'b10100: begin {T,C}= { 1'b0,        t };         end // shr1
                5'b10101: begin {C,T}= sum; a= t;    b= t; cin= 0; end // shl1
                5'b10110: begin     T= { 4'b0000,t[W-1:4] }; C= t; end // shr4
                5'b10111: begin     T= { t[W-5:0],4'b0000 }; C= t; end // shl4

                // --- GROUP 3: Stack Mutation & Return Stack Hooks (248-255) ---
                5'b11000: begin           {T,N}= mul;                   end // mul
                5'b11001: begin sd=-1; rd= 1; T= n;                     end // >r
                5'b11010: begin sd= 1;        T= r;                     end // @r
                5'b11011: begin sd= 1; rd=-1; T= r;                     end // r>
                5'b11100: begin sd= 1;        T= t;                     end // tuck
                5'b11101: begin sd= 1;        T= n;                     end // over
                5'b11110: begin sd= 1;        T= t;                     end // dup
                5'b11111: begin sd= 1;        T= ones;                  end // true
            endcase
        end
    end

endmodule
