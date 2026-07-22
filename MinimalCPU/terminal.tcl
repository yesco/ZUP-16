# build.tcl - CLI Build Execution Script
set_device -name GW2AR-LV18QN88C8/I7

# Add isolated dependencies
add_file uart/uart_tx.v
add_file uart/uart_rx.v
add_file dvi_tx/dvi_tx.v
add_file gowin_rpll/gowin_rpll.v

# Add master system logic and pin allocations
add_file top_terminal.v
add_file terminal_pins.cst

# Set the explicit top-level module to override file name confusion
set_option -top_module top_terminal

# Run compilation chain
run synthesis
run pnr
