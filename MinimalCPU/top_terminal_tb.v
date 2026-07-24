`timescale 1ns/1ps

module top_terminal_tb;

    reg        clk_27m;
    reg        rst_n;
    wire       sim_rx = 1'b1;
    wire       sim_tx;
    
    wire [2:0] tmds_p, tmds_n;
    wire [2:0] tmds_clk_p, tmds_clk_n;

    reg [7:0]  sim_direct_char;
    reg        sim_direct_valid;

    integer stdin_fd;
    integer input_char;
    reg     exit_request;

    top_terminal uut (
        .sys_clk(clk_27m), .sys_rst_n(rst_n),
        .uart_rx(sim_rx), .uart_tx(sim_tx),
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_p), .tmds_data_n(tmds_n)
    );

    // Free-running simulation clock thread
    initial clk_27m = 1'b0;
    always begin
        #18.518 clk_27m = ~clk_27m;
    end

    task trigger_instant_echo;
        input [7:0] echo_char;
        begin
            if (echo_char == 8'h0D || echo_char == 8'h0A) begin
                $write("%c%c", 8'h0D, 8'h0A); 
            end else begin
                $write("%c", echo_char);
            end
            $fflush();
        end
    endtask

    initial begin
        rst_n            = 1'b0;
        sim_direct_char  = 8'h00;
        sim_direct_valid = 1'b0;
        exit_request     = 1'b0;

        #500;
        rst_n = 1'b1;
        
        $write("%c%c========================================================%c%c", 8'h0D, 8'h0A, 8'h0D, 8'h0A);
        $write(" YESCO INSTANT SIMULATOR: Type your letters below!%c%c", 8'h0D, 8'h0A);
        $write(" (Press Ctrl+C or type '!' to close simulation runtime)%c%c", 8'h0D, 8'h0A);
        $write("========================================================%c%c", 8'h0D, 8'h0A);
        $fflush();
    end

    // Unix Keyboard Input Loop
    initial begin
        #1000;
        stdin_fd = $fopen("/dev/stdin", "r");
        if (stdin_fd == 0) $finish;

        while (!exit_request) begin
            input_char = $fgetc(stdin_fd);
            if (input_char != -1) begin
                if (input_char == "!") begin
                    exit_request = 1'b1;
                end else begin
                    // Assert the character onto the bus
                    @(posedge clk_27m);
                    sim_direct_char  = input_char[7:0];
                    sim_direct_valid = 1'b1;
                    
                    // Keep the valid strobe up for exactly 4 clock edges 
                    // so the CPU is guaranteed to catch it
                    repeat(4) @(posedge clk_27m);
                    
                    // Clear the valid strobe cleanly from the testbench side
                    sim_direct_valid = 1'b0;
                end
            end
            // Small time delay to keep your Unix host processor stable
            #50; 
        end

        $write("%c%c[STATUS] Terminating live interactive loop simulation.%c%c", 8'h0D, 8'h0A, 8'h0D, 8'h0A);
        $fflush();
        $finish;
    end

endmodule
