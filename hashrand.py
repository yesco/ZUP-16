import sys
import argparse

def fixed_rand_hash_instruction(tos, nos):
    """
    100% Deterministic, Stateless Rand/Hash Instruction.
    """
    if tos != 0:
        # STRING HASH MODE
        rot7_nos = ((nos << 7) & 0xFFFF) | (nos >> 9)
        return rot7_nos ^ tos
    else:
        # RANDOM MODE (TOS == 0)
        # 1. Pre-cancel Left Rotate 7 by Right Rotating 7 (Left 9)
        unrotated_nos = ((nos >> 7) & 0xFFFF) | ((nos << 9) & 0xFFFF)
        
        # 2. Apply a clean, full-period LCG step (x * 5 + 1)
        lcg_step = ((unrotated_nos * 5) + 1) & 0xFFFF
        
        # 3. Left Rotate 7 fabric execution
        result_out = ((lcg_step << 7) & 0xFFFF) | (lcg_step >> 9)
        return result_out

def count_bits_changed(val1, val2):
    """Calculates the Hamming distance (number of bit changes) between two integers."""
    return bin((val1 ^ val2) & 0xFFFF).count('1')

def run_sequence_verification(starting_seed=0):
    """Runs a full 65,536-step cycle with TOS = 0 starting from a specified number."""
    visited = [False] * 65536
    current_state = starting_seed & 0xFFFF
    
    print(f"Verifying full 64K cycle starting from custom seed: {current_state} (0x{current_state:04X})")
    print(f"{'Step':<7} | {'Decimal':<7} | {'Hex':<8} | {'Binary':<18} | {'Bits Changed':<12}")
    print("-" * 65)
    
    print(f"{0:<7} | {current_state:<7} | 0x{current_state:04X} | {current_state:016b} | {'-':<12}")
    visited[current_state] = True
    
    previous_state = current_state
    for step in range(1, 65536):
        current_state = fixed_rand_hash_instruction(tos=0, nos=previous_state)
        visited[current_state] = True
        
        bits_changed = count_bits_changed(previous_state, current_state)
        print(f"{step:<7} | {current_state:<7} | 0x{current_state:04X} | {current_state:016b} | {bits_changed:<12}")
        previous_state = current_state
        
    final_step = fixed_rand_hash_instruction(tos=0, nos=previous_state)
    print("-" * 65)
    print(f"Loop Closure Verification -> Next Step would be: {final_step} (Should match seed: {starting_seed})")
    print(f"Total Unique Values Visited: {sum(visited)} / 65536")

def run_string_hash(input_string, initial_seed=0):
    """Simulates character-by-character string hashing with an optional custom type/domain seed."""
    current_hash = initial_seed & 0xFFFF
    
    print(f"Hashing String: \"{input_string}\" (Type Seed: {current_hash} / 0x{current_hash:04X})")
    print(f"{'Step':<5} | {'Char':<6} | {'TOS (Val)':<9} | {'Decimal':<7} | {'Hex':<8} | {'Binary':<18} | {'Bits Changed':<12}")
    print("-" * 85)
    
    # Print the custom entry state
    print(f"{0:<5} | {'START':<6} | {'-':<9} | {current_hash:<7} | 0x{current_hash:04X} | {current_hash:016b} | {'-':<12}")
    
    for idx, char in enumerate(input_string):
        tos_val = ord(char) & 0xFFFF
        next_hash = fixed_rand_hash_instruction(tos=tos_val, nos=current_hash)
        bits_changed = count_bits_changed(current_hash, next_hash)
        
        print(f"{idx+1:<5} | {repr(char):<6} | {tos_val:<9} | {next_hash:<7} | 0x{next_hash:04X} | {next_hash:016b} | {bits_changed:<12}")
        current_hash = next_hash
        
    print("-" * 85)
    print(f"Final Typed Hash Value: 0x{current_hash:04X} ({current_hash})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Stateless 16-bit Hash & Random Verification Tool")
    parser.を手動 = parser.add_argument('input_data', nargs='?', default=None, 
                        help="An integer to test 64K random cycles, or a string to test hashing.")
    parser.add_argument('--seed', type=int, default=0, 
                        help="Optional numeric seed to type/initialize string hashes.")
    
    args = parser.parse_args()
    
    # Mode 1: No arguments provided -> Run 64K loop starting at 0
    if args.input_data is None:
        run_sequence_verification(starting_seed=0)
    else:
        # Check if input is a number
        is_numeric = False
        try:
            int(args.input_data)
            is_numeric = True
        except ValueError:
            pass
            
        if is_numeric:
            # Mode 2: Input is numeric -> Run full 64K loop starting from this seed
            run_sequence_verification(starting_seed=int(args.input_data))
        else:
            # Mode 3: Input is a string -> Run hashing (optionally with the custom type seed)
            run_string_hash(args.input_data, initial_seed=args.seed)
