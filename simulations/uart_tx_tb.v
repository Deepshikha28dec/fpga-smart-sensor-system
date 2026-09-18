`timescale 1ns/1ps
`default_nettype none

module uart_tx_tb;

    /*
     * Use a smaller clock/baud ratio for faster simulation.
     */
    localparam integer CLOCK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE     = 100_000;

    localparam integer CLKS_PER_BIT =
        CLOCK_FREQ_HZ / BAUD_RATE;

    localparam integer CLOCK_PERIOD_NS = 1000;


    reg clk;
    reg reset;
    reg en;

    reg [7:0] data;

    wire busy;
    wire uart_tx;


    uart_tx #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .BAUD_RATE     (BAUD_RATE)
    ) dut (
        .clk     (clk),
        .reset   (reset),
        .en      (en),
        .data    (data),
        .busy    (busy),
        .uart_tx (uart_tx)
    );


    /*
     * System clock.
     */
    initial
    begin
        clk = 1'b0;

        forever
            #(CLOCK_PERIOD_NS / 2)
            clk = ~clk;
    end


    /*
     * Send one byte through the DUT.
     */
    task send_byte;
        input [7:0] value;

        begin
            wait (!busy);

            @(posedge clk);

            data <= value;
            en   <= 1'b1;

            @(posedge clk);

            en <= 1'b0;

            wait (!busy);
        end
    endtask


    initial
    begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);

        reset = 1'b1;
        en    = 1'b0;
        data  = 8'h00;

        repeat (4)
            @(posedge clk);

        reset = 1'b0;

        /*
         * Test transmission of ASCII 'H'.
         */
        send_byte(8'h48);

        repeat (5 * CLKS_PER_BIT)
            @(posedge clk);

        $display("UART transmission simulation completed.");

        $finish;
    end

endmodule

`default_nettype wire