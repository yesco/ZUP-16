def fixed_rand_hash_instruction(tos, nos):
    """
    100% Deterministic, Stateless Rand/Hash Instruction.
    """
    if tos != 0:
        # STRING HASH MODE (Unchanged)
        rot7_nos = ((nos << 7) & 0xFFFF) | (nos >> 9)
        return rot7_nos ^ tos
    else:
        # RANDOM MODE (TOS == 0)
        # 1. Pre-cancel the fabric's upcoming Left Rotate 7 by Right Rotating 7 (Left 9)
        # This costs 0 LUTs in an FPGA; it is just a fixed wire re-mapping.
        unrotated_nos = ((nos >> 7) & 0xFFFF) | ((nos << 9) & 0xFFFF)
        
        # 2. Apply a clean, full-period LCG step (x * 5 + 1) to the unrotated state
        # In Verilog: x + (x << 2) + 1
        lcg_step = ((unrotated_nos * 5) + 1) & 0xFFFF
        
        # 3. YOUR EXACT HARDWARE FABRIC (Left Rotate 7)
        # The Left Rotate 7 here perfectly cancels the Right Rotate 7 above,
        # forcing the output of the instruction to be exactly a clean LCG step.
        result_out = ((lcg_step << 7) & 0xFFFF) | (lcg_step >> 9)
        return result_out

def run_proof():
    visited = [False] * 65536
    sequence = []
    current_state = 0 # Booting safely from 0
    
    print("Simulating fixed stateless loop (TOS = 0)...")
    for _ in range(65536):
        sequence.append(current_state)
        visited[current_state] = True
        current_state = fixed_rand_hash_instruction(tos=0, nos=current_state)
        
    total_visited = sum(visited)
    print(f"-> Total unique numbers visited: {total_visited} (Out of 65536)")
    print(f"-> Was 0 visited successfully?  {visited[0]}")
    
    if total_visited == 65536:
        print("\nSUCCESS: Perfectly uniform 64K cycle without missing a single value!")

if __name__ == "__main__":
    run_proof()
