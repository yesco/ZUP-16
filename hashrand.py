import sys
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Unified Single-Path Hash and Rand Simulator")
    parser.add_argument('input_data', nargs='?', default=None)
    parser.add_argument('--seed', type=int, default=47111)
    args = parser.parse_args()

    # Hardware State Register initialization (Stack NOS)
    current_nos = args.seed & 0xFFFF

    # =========================================================================
    # UNIFIED STREAM PREPARATION (Translates inputs into a single TOS array)
    # =========================================================================
    tos_stream = []

    if args.input_data is None:
        # Random Verification Mode: A sequence of 65,536 zeros
        print(f"Running full 64K random verification loop from seed: {current_nos} (0x{current_nos:04X})")
        tos_stream = [0] * 65536
    else:
        try:
            # If the argument is an integer, treat it as a seed and run the 64K random loop
            current_nos = int(args.input_data) & 0xFFFF
            print(f"Running full 64K random verification loop from custom seed: {current_nos} (0x{current_nos:04X})")
            tos_stream = [0] * 65536
        except ValueError:
            # If the argument is a string, stream its characters (strlen)
            print(f"Hashing String: \"{args.input_data}\" (Type Seed: {current_nos} / 0x{current_nos:04X})")
            for char in args.input_data:
                tos_stream.append(ord(char) & 0xFFFF)

    # =========================================================================
    # THE UNIFIED HARDWARE DATA PATH (Exactly one loop, one path)
    # =========================================================================
    print("-" * 85)
    print(f"{'Step':<5} | {'TOS (In)':<9} | {'NOS (Out)':<9} | {'Hex':<8} | {'Binary':<18} | {'Bits Changed':<12}")
    print("-" * 85)

    # Step 0 Baseline Print
    print(f"{0:<5} | {'START':<9} | {current_nos:<9} | 0x{current_nos:04X} | {current_nos:016b} | {'-':<12}")

    visited_count = [False] * 65536
    previous_nos = current_nos

    # Loop length is determined entirely by the data stream (strlen or 65536)
    for step_idx, tos_val in enumerate(tos_stream):
        
        # 1. THE COMBINATIONAL ALU FABRIC: (NOS rot 7) ^ TOS
        # Wires rotate current state left by 7, then bitwise XOR with incoming TOS
        alu_rot7 = ((current_nos << 7) & 0xFFFF) | (current_nos >> 9)
        instruction_output = alu_rot7 ^ tos_val

        # 2. THE REGISTER WRITE-BACK BOUNDARY MULTIPLEXER: if (TOS == 0)
        # Evaluated at the flip-flop clock pins to update the register for the next step
        if tos_val == 0:
            # Multiplierless LCG: (nos << 2) + nos + Cin
            nos_shift_left_2 = (current_nos << 2) & 0xFFFF
            current_nos = (nos_shift_left_2 + current_nos + 1) & 0xFFFF
        else:
            # Accumulate the raw XOR fabric output
            current_nos = instruction_output

        # Trace and visualize tracking telemetry
        visited_count[current_nos] = True
        bits_changed = bin((previous_nos ^ current_nos) & 0xFFFF).count('1')
        previous_nos = current_nos

        # Print the execution line dynamically
        print(f"{step_idx+1:<5} | {tos_val:<9} | {current_nos:<9} | 0x{current_nos:04X} | {current_nos:016b} | {bits_changed:<12}")

    # =========================================================================
    # POST-STREAM ANALYSIS
    # =========================================================================
    print("-" * 85)
    if len(tos_stream) == 65536:
        print(f"Total Unique ALU Values Generated across the 64K loop: {sum(visited_count)} / 65536")
    else:
        print(f"Final Accumulator Hash Value: 0x{current_nos:04X} ({current_nos})")
