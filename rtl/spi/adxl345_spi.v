`timescale 1ns/1ps
`default_nettype none

/*
 * ADXL345 SPI Register Interface
 *
 * Implements single-byte register read/write transactions.
 *
 * ADXL345 command byte:
 *
 *   bit 7   : R/W   (1 = read, 0 = write)
 *   bit 6   : MB    (0 = single-byte transaction)
 *   bits 5:0: register address
 *
 * SPI configuration:
 *   Mode 3
 *   CPOL = 1
 *   CPHA = 1
 *
 * Default:
 *   FPGA clock : 12 MHz
 *   SPI clock  : 1 MHz
 */

module adxl345_spi #(
    parameter integer CLOCK_FREQ_HZ = 12_000_000,
    parameter integer SPI_FREQ_HZ   = 1_000_000
) (
    input  wire       clk,
    input  wire       reset,

    input  wire       start,
    input  wire       read_write,
    input  wire [5:0] address,
    input  wire [7:0] write_data,

    output reg  [7:0] read_data,
    output reg        busy,
    output reg        done,

    input  wire       spi_miso,
    output reg        spi_mosi,
    output reg        spi_clk,
    output reg        spi_cs_n
);

    localparam integer HALF_PERIOD_CLKS =
        CLOCK_FREQ_HZ / (2 * SPI_FREQ_HZ);

    localparam integer DIV_WIDTH =
        (HALF_PERIOD_CLKS <= 1)
        ? 1
        : $clog2(HALF_PERIOD_CLKS);

    reg [DIV_WIDTH-1:0] clk_divider;

    reg [15:0] tx_shift;
    reg [3:0]  bit_index;

    reg read_transaction;


    always @(posedge clk)
    begin
        if (reset)
        begin
            clk_divider      <= 0;
            tx_shift         <= 16'd0;
            bit_index        <= 4'd15;
            read_transaction <= 1'b0;

            read_data        <= 8'd0;

            busy             <= 1'b0;
            done             <= 1'b0;

            spi_mosi         <= 1'b0;
            spi_clk          <= 1'b1;
            spi_cs_n         <= 1'b1;
        end
        else
        begin
            /*
             * done is a one-clock pulse.
             */
            done <= 1'b0;

            /*
             * Start a new SPI transaction.
             */
            if (start && !busy)
            begin
                busy             <= 1'b1;
                spi_cs_n         <= 1'b0;
                spi_clk          <= 1'b1;

                clk_divider      <= 0;
                bit_index        <= 4'd15;
                read_transaction <= read_write;

                /*
                 * First byte:
                 *   R/W | MB | address[5:0]
                 *
                 * Second byte:
                 *   write data for write transactions
                 *   dummy byte for read transactions
                 */
                tx_shift <= {
                    read_write,
                    1'b0,
                    address,
                    read_write ? 8'h00 : write_data
                };
            end

            else if (busy)
            begin
                /*
                 * Generate SPI clock from the FPGA system clock.
                 */
                if (clk_divider == HALF_PERIOD_CLKS - 1)
                begin
                    clk_divider <= 0;

                    /*
                     * Mode 3:
                     *
                     * Falling edge:
                     * update MOSI.
                     */
                    if (spi_clk)
                    begin
                        spi_clk  <= 1'b0;
                        spi_mosi <= tx_shift[bit_index];
                    end

                    /*
                     * Rising edge:
                     * sample MISO.
                     */
                    else
                    begin
                        spi_clk <= 1'b1;

                        /*
                         * The second received byte contains
                         * register data during a read.
                         */
                        if (read_transaction &&
                            (bit_index < 4'd8))
                        begin
                            read_data[bit_index] <= spi_miso;
                        end

                        if (bit_index == 4'd0)
                        begin
                            busy     <= 1'b0;
                            done     <= 1'b1;
                            spi_cs_n <= 1'b1;
                            spi_mosi <= 1'b0;
                        end
                        else
                        begin
                            bit_index <= bit_index - 1'b1;
                        end
                    end
                end
                else
                begin
                    clk_divider <= clk_divider + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire