`timescale 1ns/1ps
`default_nettype none

/*
 * UART transmitter - 8N1
 *
 * Default configuration:
 *   Clock     : 12 MHz
 *   Baud rate : 9600
 *   Data bits : 8
 *   Parity    : none
 *   Stop bits : 1
 *
 * Transmission begins when 'en' is asserted while the
 * transmitter is idle.
 *
 * Data is transmitted LSB first.
 */

module uart_tx #(
    parameter integer CLOCK_FREQ_HZ = 12_000_000,
    parameter integer BAUD_RATE     = 9_600
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       en,
    input  wire [7:0] data,
    output reg        busy,
    output reg        uart_tx
);

    localparam integer CLKS_PER_BIT =
        CLOCK_FREQ_HZ / BAUD_RATE;

    localparam [2:0]
        STATE_IDLE  = 3'd0,
        STATE_START = 3'd1,
        STATE_DATA  = 3'd2,
        STATE_STOP  = 3'd3;

    reg [2:0] state;

    reg [7:0] data_reg;
    reg [2:0] bit_index;

    reg [$clog2(CLKS_PER_BIT)-1:0] baud_counter;


    always @(posedge clk)
    begin
        if (reset)
        begin
            state        <= STATE_IDLE;
            data_reg     <= 8'd0;
            bit_index    <= 3'd0;
            baud_counter <= 0;

            uart_tx      <= 1'b1;
            busy         <= 1'b0;
        end
        else
        begin
            case (state)

                /*
                 * UART line remains HIGH while idle.
                 */
                STATE_IDLE:
                begin
                    uart_tx      <= 1'b1;
                    busy         <= 1'b0;
                    baud_counter <= 0;
                    bit_index    <= 0;

                    if (en)
                    begin
                        data_reg <= data;
                        busy     <= 1'b1;
                        state    <= STATE_START;
                    end
                end


                /*
                 * Start bit = LOW.
                 */
                STATE_START:
                begin
                    uart_tx <= 1'b0;

                    if (baud_counter == CLKS_PER_BIT - 1)
                    begin
                        baud_counter <= 0;
                        state        <= STATE_DATA;
                    end
                    else
                    begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end


                /*
                 * Send eight data bits, LSB first.
                 */
                STATE_DATA:
                begin
                    uart_tx <= data_reg[bit_index];

                    if (baud_counter == CLKS_PER_BIT - 1)
                    begin
                        baud_counter <= 0;

                        if (bit_index == 3'd7)
                        begin
                            bit_index <= 0;
                            state     <= STATE_STOP;
                        end
                        else
                        begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                    else
                    begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end


                /*
                 * Stop bit = HIGH.
                 */
                STATE_STOP:
                begin
                    uart_tx <= 1'b1;

                    if (baud_counter == CLKS_PER_BIT - 1)
                    begin
                        baud_counter <= 0;
                        busy         <= 1'b0;
                        state        <= STATE_IDLE;
                    end
                    else
                    begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end


                default:
                begin
                    state   <= STATE_IDLE;
                    uart_tx <= 1'b1;
                    busy    <= 1'b0;
                end

            endcase
        end
    end

endmodule

`default_nettype wire