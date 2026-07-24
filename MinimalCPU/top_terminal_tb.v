`timescale 1ns/1ps

module top_terminal_tb;

    reg        clk_27m;
    reg        rst_n;
    wire       sim_rx = 1'b1;
    wire       sim_tx;
    
    wire [2:0] tmds_p, tmds_n;
    wire [2:0] tmds_clk_p, tmds_clk_n;

    // Direct simulation speed bus wires
    reg [7:0]  sim_direct_char;
    reg        sim_direct_valid;

    integer stdin_fd;
    integer input_char;

    top_terminal uut (
        .sys_clk(clk_27m), .sys_rst_n(rst_n),
        .uart_rx(sim_rx), .uart_tx(sim_tx),
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_p), .tmds_data_n(tmds_n)
    );

    always begin
        #18.518 clk_27m = ~clk_27m;
    end

    // Task called directly by the hardware module to print characters instantly
    task trigger_instant_echo;
        input [7:0] echo_char;
        begin
            $write("%c", echo_char);
            $fflush();
        end
    endtask

    initial begin
        clk_27m          = 1'b0;
        rst_n            = 1'b0;
        sim_direct_char  = 8'h00;
        sim_direct_valid = 1'b0;

        #500;
        rst_n = 1'b1;
        #2000;

        stdin_fd = $fopen("/dev/stdin", "r");
        if (stdin_fd == 0) $finish;

        $display("\n========================================================");
        $display(" YESCO INSTANT SIMULATOR: Type your letters below!");
        $display(" (Press Ctrl+C or type '!' to exit simulation loop)");
        $display("========================================================\n");

        while (1) begin
            input_char = $fgetc(stdin_fd);
            if (input_char != -1) begin
                if (input_char == "!") $finish;
                
                // Assert the data to the custom CPU in exactly 1 clock cycle!
                @(posedge clk_27m);
                sim_direct_char  = input_char[7:0];
                sim_direct_valid = 1'b1;
                
                @(posedge clk_27m);
                sim_direct_valid = 1'b0;
            end
            repeat(5) @(posedge clk_27m);
        end
    end

endmodule
