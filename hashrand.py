import sys
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plain Logic Hash and Rand Simulator")
    parser.add_argument('input_data', nargs='?', default=None)
#    parser.add_argument('--seed', type=int, default=47111)
    parser.add_argument('--seed', type=int, default=0)
    args = parser.parse_args()

    # Define base 16-bit register tracking space
    # In Verilog: reg [15:0] current_nos;
    current_nos = args.seed & 0xFFFF

    # =========================================================================
    # MODE 1: SEQUENCE VERIFICATION (No arguments provided)
    # =========================================================================
    if args.input_data is None:
        visited = [False] * 65536
        previous_out = None
        
        print(f"Verifying full 64K cycle starting from seed: {current_nos} (0x{current_nos:04X})")
        print(f"{'Step':<7} | {'Decimal':<7} | {'Hex':<8} | {'Binary':<18} | {'Bits Changed':<12}")
        print("-" * 65)

        for step in range(65536):
            # -----------------------------------------------------------------
            # COMP_PATH: Your 1-Stage Combinational ALU Fabric
            # Verilog equivalent: wire [15:0] rot7 = {nos[8:0], nos[15:9]}; 
            #                     wire [15:0] out = rot7 ^ 16'd0;
            # -----------------------------------------------------------------
            alu_rot7 = ((current_nos << 7) & 0xFFFF) | (current_nos >> 9)
            instruction_output = alu_rot7 ^ 0  # TOS is explicitly 0 in random mode
            
            # Trace visited properties
            visited[instruction_output] = True

            # Calculate bit changes from previous turn (Hamming Distance)
            if previous_out is not None:
                xor_diff = (previous_out ^ instruction_output) & 0xFFFF
                bits_changed = bin(xor_diff).count('1')
            else:
                bits_changed = "-"

            print(f"{step:<7} | {instruction_output:<7} | 0x{instruction_output:04X} | {instruction_output:016b} | {bits_changed:<12}")

            # -----------------------------------------------------------------
            # REG_BOUNDARY_PATH: Parallel State Increment Loop
            # Verilog equivalent: wire [15:0] lcg = {nos[13:0], 2'b00} + nos + 16'd1;
            #                     always @(posedge clk) nos <= (tos==0) ? lcg : out;
            # -----------------------------------------------------------------
            previous_out = instruction_output
            
            # Since TOS is 0, the write-back mux selects the multiplierless LCG step
            nos_shift_left_2 = (current_nos << 2) & 0xFFFF
            lcg_adder_ripple = nos_shift_left_2 + current_nos + 1  # Carry-In (Cin) is 1
            current_nos = lcg_adder_ripple & 0xFFFF

        # Final check to prove closure loop
        final_rot7 = ((current_nos << 7) & 0xFFFF) | (current_nos >> 9)
        final_output = final_rot7 ^ 0
        print("-" * 65)
        print(f"Loop Closure Verification -> Next Output would be: {final_output}")
        print(f"Total Unique ALU Values Generated: {sum(visited)} / 65536")

    # =========================================================================
    # MODE 2 & 3: PROCESSING INJECTIONS OR STRINGS
    # =========================================================================
    else:
        # Evaluate if the input data represents a number or string text
        is_numeric = False
        try:
            int(args.input_data)
            is_numeric = True
        except ValueError:
            pass

        # Sub-Mode A: Input is a specific numeric entry point -> Run 64K loop verification
        if is_numeric:
            current_nos = int(args.input_data) & 0xFFFF
            visited = [False] * 65536
            previous_out = None
            
            print(f"Verifying full 64K cycle starting from seed: {current_nos} (0x{current_nos:04X})")
            print(f"{'Step':<7} | {'Decimal':<7} | {'Hex':<8} | {'Binary':<18} | {'Bits Changed':<12}")
            print("-" * 65)

            for step in range(65536):
                alu_rot7 = ((current_nos << 7) & 0xFFFF) | (current_nos >> 9)
                instruction_output = alu_rot7 ^ 0
                visited[instruction_output] = True

                if previous_out is not None:
                    bits_changed = bin((previous_out ^ instruction_output) & 0xFFFF).count('1')
                else:
                    bits_changed = "-"

                print(f"{step:<7} | {instruction_output:<7} | 0x{instruction_output:04X} | {instruction_output:016b} | {bits_changed:<12}")

                previous_out = instruction_output
                nos_shift_left_2 = (current_nos << 2) & 0xFFFF
                current_nos = (nos_shift_left_2 + current_nos + 1) & 0xFFFF

            final_rot7 = ((current_nos << 7) & 0xFFFF) | (current_nos >> 9)
            final_output = final_rot7 ^ 0
            print("-" * 65)
            print(f"Loop Closure Verification -> Next Output would be: {final_output}")
            print(f"Total Unique ALU Values Generated: {sum(visited)} / 65536")

        # Sub-Mode B: Input is a string -> Run character-by-character deterministic hash avalanche
        else:
            input_string = args.input_data
            print(f"Hashing String: \"{input_string}\" (Type Seed: {current_nos} / 0x{current_nos:04X})")
            print(f"{'Step':<5} | {'Char':<6} | {'TOS (Val)':<9} | {'Decimal':<7} | {'Hex':<8} | {'Binary':<18} | {'Bits Changed':<12}")
            print("-" * 85)
            
            print(f"{0:<5} | {'START':<6} | {'-':<9} | {current_nos:<7} | 0x{current_nos:04X} | {current_nos:016b} | {'-':<12}")
            
            for idx, char in enumerate(input_string):
                # -------------------------------------------------------------
                # FETCH INPUTS: Extract character byte configuration
                # -------------------------------------------------------------
                tos_val = ord(char) & 0xFFFF
                previous_nos = current_nos

                # -------------------------------------------------------------
                # ALU FABRIC EXECUTION
                # -------------------------------------------------------------
                alu_rot7 = ((current_nos << 7) & 0xFFFF) | (current_nos >> 9)
                instruction_output = alu_rot7 ^ tos_val

                # -------------------------------------------------------------
                # REG_BOUNDARY MUX SELECTION: If TOS != 0, capture raw output wire
                # -------------------------------------------------------------
                if tos_val == 0:
                    nos_shift_left_2 = (current_nos << 2) & 0xFFFF
                    current_nos = (nos_shift_left_2 + current_nos + 1) & 0xFFFF
                else:
                    current_nos = instruction_output

                bits_changed = bin((previous_nos ^ current_nos) & 0xFFFF).count('1')
                print(f"{idx+1:<5} | {repr(char):<6} | {tos_val:<9} | {current_nos:<7} | 0x{current_nos:04X} | {current_nos:016b} | {bits_changed:<12}")
                
            print("-" * 85)
            print(f"Final Typed Hash Value: 0x{current_nos:04X} ({current_nos})")
