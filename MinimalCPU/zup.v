module zup #(
    parameter W = 16
)(
    input  wire [7:0]  op,    // Full 8-bit instruction token
    input  wire [W-1:0] t,    // Current Top of Stack (Live/Bypassed)
    input  wire [W-1:0] n,    // Current Next on Stack (Live/Bypassed)
    input  wire [W-1:0] r,    // Current Return Stack Top (Live/Bypassed)
    input  wire         c,    // Live Carry input flag
    
    output reg  [W-1:0] T,    // New Top of Stack out
    output reg          C,    // New Carry output flag
    output reg  [1:0]   sd,   // Data Stack Pointer Delta (0, 1, -1)
    output reg  [1:0]   rd,   // Return Stack Pointer Delta (0, 1, -1)
);

    wire [W-1:0] zeroes = {W{1'b0}};
    wire [W-1:0] ones   = {W{1'b1}};

    // Unified 5-bit opcode key (combines group g and sub-opcode i)
    wire is_op = op[7];
    wire [4:0] key = op[4:0];

    // Core adder hookups running in parallel
    reg  [W-1:0]   a, b;
    reg            cin;
    wire [W:0]     sum = a + b + cin;
    wire [2*W-1:0] mul = n * t;

    always @(*) begin
        // Baseline global hardware defaults (Overridden explicitly by match rows below)
        T=t; C=0; spd=0; rpd=0; en_jp=0; a=n; b=t; cin=0;

        if (sd == -1) begin T= n; N= n2; refill; end
        if (sd == +1) begin N= t; N2= n; spill;  end

        if (rd == -1) begin R= r2; refill; end
        if (rd == +1) begin R2= r; spill;  end
 
        if (!is_op) begin

            T = op; spd= 1; // Literal flag processing

        end else begin
            case (key)
                // --- GROUP 0: Two-Argument Reductions (224-231) ---
                5'b00000: begin {C,T}= sum; sd=-1; a= n; b= t;  cin= 0; end // add
                5'b00001: begin {C,T}= sum; sd=-1; a= n; b= t;  cin= c; end // adc
                5'b00010: begin {C,T}= sum; sd=-1; a= n; b=~t;  cin= 1; end // sub
                5'b00011: begin T= t;       sd=-1;                      end // nip
                5'b00100: begin T= n & t;   sd=-1;                      end // and
                5'b00101: begin T= n | t;   sd=-1;                      end // or
                5'b00110: begin T= n ^ t;   sd=-1;                      end // xor
	        5'b00111: begin T= n;       sd=-1;                      end // drop
	      
                // --- GROUP 1: Control Flow & Inversions (232-239) ---
                5'b01000: begin T= ~t;                           end // not
                5'b01001: begin {C,T}= sum; a= 0; b= ~t; cin= 1; end // neg
                5'b01010: begin T= t;                            end // nop
                5'b01011: begin T= n;                            end // swap
                5'b01100: begin T= n;                            end // rot
                5'b01101: begin sd=-1; if (!n) PC= t;            end // zjp
                5'b01110: begin sd=-1; if (!c) PC= t;            end // zjp
                5'b01111: begin rpd= -1; T= t;                   end // ret

                // --- GROUP 2: Math Modifiers and Shifters (240-247) ---
                5'b10000: begin {C,T}= sum; a= zeroes; b= t; cin= 1; end // inc
                5'b10001: begin {C,T}= sum; a= ones;   b= t; cin= 0; end // dec
                5'b10010: begin {T,C}= t;                            end // asr
                5'b10011: begin {T,C}= { t[W-1], t };                end // ror
                5'b10100: begin {T,C}= t;                            end // shr1
                5'b10101: begin {C,T}= sum; a= t;      b= t; cin= 0; end // shl1
                5'b10110: begin T= { 4'b0000, t[W-1:4] };  C= t[4];  end // shr4
                5'b10111: begin T= { t[W-5:0], 4'b0000 };  C= t[5];  end // shl4

                // --- GROUP 3: Stack Mutation & Return Stack Hooks (248-255) ---
                5'b11000: begin        {T,N}= mul;  end // mul
                5'b11001: begin sd=-1; T= n; rd= 1; end // >r
                5'b11010: begin sd= 1; T= r;        end // @r
                5'b11011: begin sd= 1; T= r; rd=-1; end // r>
                5'b11100: begin sd= 1; T= t;        end // tuck
                5'b11101: begin sd= 1; T= n;        end // over
                5'b11110: begin sd= 1; T= t;        end // dup
                5'b11111: begin sd= 1; T= ones;     end // true
            endcase
        end
    end

endmodule
