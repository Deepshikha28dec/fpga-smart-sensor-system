`default_nettype none

/*
 * Frequency-divided binary counter.
 *
 * The module derives a lower-frequency enable event from
 * the FPGA system clock and increments an 8-bit counter.
 *
 * Default configuration:
 *
 *   System clock : 12 MHz
 *   Update rate  : 3 Hz
 */

module slow_counter #(
    parameter integer CLK_FREQ_HZ    = 12_000_000,
    parameter integer UPDATE_FREQ_HZ = 3
) (
    input  wire       clk,
    input  wire       reset,
    output reg [7:0] counter
);

    localparam integer DIVISOR =
        CLK_FREQ_HZ / UPDATE_FREQ_HZ;

    reg [31:0] divider_counter;

    always @(posedge clk)
    begin
        if (reset)
        begin
            divider_counter <= 32'd0;
            counter         <= 8'd0;
        end
        else if (divider_counter == (DIVISOR - 1))
        begin
            divider_counter <= 32'd0;
            counter         <= counter + 1'b1;
        end
        else
        begin
            divider_counter <= divider_counter + 1'b1;
        end
    end

endmodule

`default_nettype wire