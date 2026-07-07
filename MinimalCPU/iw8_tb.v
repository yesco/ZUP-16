`timescale 1ns / 1ps

module iw8_tb;

   // Testbench signals
   reg       clk;
   reg       rst_n;
   reg [7:0] op;
   wire[7:0] PC;
   wire      z;

   // Instantiate the Device Under Test (DUT)
   iw8 uut (
      .clk(clk),
      .rst_n(rst_n),
      .PC(PC),
      .op(op),
      .z(z)
   );

   // 50MHz Clock Generation
   always #10 clk = ~clk;

   // Main Simulation Block
   initial begin
      // Setup Initial State
      clk = 0;
      rst_n = 0;
      op = 8'h00;

      // Assert Synchronous Reset
      #40;
      rst_n = 1;
      #20;

      $display("=== STARTING IW8 PROCESSOR TESTBENCH ===");

      // --------------------------------------------------------
      // TEST 1: Literal Load (op[7]=0) -> T should get value
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b0010_1010; // Load Literal 42 (0x2A) into T
      $display("[Time %0t] Instruction: LITERAL 42 (op=0x%h)", $time, op);

      // --------------------------------------------------------
      // TEST 2: Duplicate via Stack Movement (op[6:5] = 2'b01)
      // This will copy T (42) into N on the next rising edge
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b1010_0000; // DUP operation (Stack movement shifts T to N)
      $display("[Time %0t] Instruction: DUP (op=0x%h) -> Moving 42 into register N", $time, op);

      // --------------------------------------------------------
      // TEST 3: Add Operation (T = t + n)
      // 42 (t) + 42 (n) = 84 (0x54). This should clear Z because N != 0.
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b1100_0000; // ADD (+) instruction
      $display("[Time %0t] Instruction: ADD (op=0x%h) -> T=t+n", $time, op);

      // --------------------------------------------------------
      // TEST 4: Conditional %BRANCH (Failed condition)
      // op = 8'b1100_0110. Bit 4=0 (Conditional).
      // Since N is 42, !n is 0, vector matches 9'b11000_0_110.
      // Condition fails: PC should increment normally (PC = pc + 1).
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b1100_0110; // %BRANCH destination attempt (Will fail because N=42, z=0)
      $display("[Time %0t] Instruction: CONDITIONAL BRANCH (op=0x%h) [Should FAIL because N!=0]", $time, op);
      #1; // Small delta step to evaluate combinational logic output
      if (z == 1) $display("   ERROR: Z flag high when N is non-zero.");

      // --------------------------------------------------------
      // TEST 5: Drop to Clear Stack (op[6:5] = 2'b10)
      // Moving N back into T. We do this to restore a zero back to register N.
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b1100_0111; // DROP operation (Stack movement shifts n to t, clears N)
      $display("[Time %0t] Instruction: DROP (op=0x%h) -> Resetting register N back to 0", $time, op);
      
      // --------------------------------------------------------
      // TEST 6: Conditional %BRANCH (Successful condition)
      // Now that N = 0, !n becomes 1. Vector matches 9'b11000_1_110.
      // Condition passes: PC should instantly jump to value inside T!
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b1100_0110; // %BRANCH destination target to T
      $display("[Time %0t] Instruction: CONDITIONAL BRANCH (op=0x%h) [Should PASS because N==0]", $time, op);
      #1;
      if (z == 0) $display("   ERROR: Z flag low when N is zero.");

      // --------------------------------------------------------
      // TEST 7: Unconditional GOTO
      // op = 8'b1101_0110. Bit 4=1 (Unconditional).
      // Vector matches 9'b11010_1_110 (if N==0) or 9'b11010_0_110 (if N!=0).
      // Both match your 9'b110?1_1_110 mask rule. PC should change to T.
      // --------------------------------------------------------
      @(posedge clk);
      op = 8'b1101_0110; // GOTO instruction
      $display("[Time %0t] Instruction: UNCONDITIONAL GOTO (op=0x%h) [Should ALWAYS jump]", $time, op);

      // Finish cycle simulation
      @(posedge clk);
      op = 8'h00; // Idle
      #40;
      
      $display("=== SIMULATION COMPLETED SUCCESFULLY ===");
      $finish;
   //
   end

   // Real-time Bus Tracker Monitoring
   initial begin
      $monitor("[CYCLE TICK] Time: %0t | PC Out: 0x%h | Op In: 8'b%b | Z-Flag Monitor: %b", 
               $time, PC, op, z);
   end

endmodule
