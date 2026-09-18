`default_nettype none

/*
 * ADXL345 Accelerometer ID Reader
 *
 * Reads the ADXL345 device-ID register (0x00)
 * through SPI and transmits the result over UART.
 *
 * Expected ADXL345 device ID:
 *     0xE5
 *
 * UART output:
 *     E5\r\n
 *
 * This application integrates:
 *
 *     FPGA
 *      |
 *      +--> SPI interface --> ADXL345
 *      |
 *      +--> UART transmitter --> PC
 */

module accelerometer_reader #(
    parameter integer CLOCK_FREQ_HZ = 12_000_000,
    parameter integer SPI_FREQ_HZ   = 1_000_000,
    parameter integer UART_BAUD     = 9_600,
    parameter integer STARTUP_CYCLES = 120_000
) (
    input  wire clk,
    input  wire reset,

    /* ADXL345 SPI */
    input  wire spi_miso,
    output wire spi_mosi,
    output wire spi_clk,
    output wire spi_cs_n,

    /* UART */
    output wire uart_tx,

    /* Debug / verification */
    output reg [7:0] sensor_id
);

    /*
     * ADXL345 device-ID register.
     */
    localparam [5:0] REG_DEVID = 6'h00;


    /*
     * Application states.
     */
    localparam [3:0]
        STATE_STARTUP        = 4'd0,
        STATE_SPI_START      = 4'd1,
        STATE_SPI_WAIT       = 4'd2,
        STATE_UART_LOAD      = 4'd3,
        STATE_UART_PULSE     = 4'd4,
        STATE_UART_WAIT_HIGH = 4'd5,
        STATE_UART_WAIT_LOW  = 4'd6,
        STATE_DONE           = 4'd7;

    reg [3:0] state;


    /*
     * Startup delay allows the sensor and FPGA interfaces
     * to settle after reset.
     */
    integer startup_counter;


    /*
     * SPI interface signals.
     */
    reg        spi_start;
    wire       spi_busy;
    wire       spi_done;
    wire [7:0] spi_read_data;


    /*
     * UART interface signals.
     */
    reg        uart_start;
    reg  [7:0] uart_data;
    wire       uart_busy;

    reg [2:0] tx_index;


    /*
     * Convert a hexadecimal nibble to ASCII.
     */
    function [7:0] hex_to_ascii;
        input [3:0] value;

        begin
            if (value < 4'd10)
                hex_to_ascii = 8'h30 + value;
            else
                hex_to_ascii = 8'h41 + (value - 4'd10);
        end
    endfunction


    /*
     * SPI register interface.
     */
    adxl345_spi #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .SPI_FREQ_HZ   (SPI_FREQ_HZ)
    ) spi_inst (
        .clk        (clk),
        .reset      (reset),

        .start      (spi_start),
        .read_write (1'b1),
        .address    (REG_DEVID),
        .write_data (8'h00),

        .read_data  (spi_read_data),
        .busy       (spi_busy),
        .done       (spi_done),

        .spi_miso   (spi_miso),
        .spi_mosi   (spi_mosi),
        .spi_clk    (spi_clk),
        .spi_cs_n   (spi_cs_n)
    );


    /*
     * UART transmitter.
     */
    uart_tx #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .BAUD_RATE     (UART_BAUD)
    ) uart_inst (
        .clk     (clk),
        .reset   (reset),
        .en      (uart_start),
        .data    (uart_data),
        .busy    (uart_busy),
        .uart_tx (uart_tx)
    );


    /*
     * Application controller.
     */
    always @(posedge clk)
    begin
        if (reset)
        begin
            state           <= STATE_STARTUP;
            startup_counter <= 0;

            spi_start       <= 1'b0;

            uart_start      <= 1'b0;
            uart_data       <= 8'h00;

            tx_index        <= 3'd0;
            sensor_id       <= 8'h00;
        end

        else
        begin
            /*
             * Control signals are one-clock pulses.
             */
            spi_start  <= 1'b0;
            uart_start <= 1'b0;


            case (state)

                /*
                 * Wait briefly after reset.
                 */
                STATE_STARTUP:
                begin
                    if (startup_counter >=
                        (STARTUP_CYCLES - 1))
                    begin
                        startup_counter <= 0;
                        state <= STATE_SPI_START;
                    end
                    else
                    begin
                        startup_counter <=
                            startup_counter + 1;
                    end
                end


                /*
                 * Start reading register 0x00.
                 */
                STATE_SPI_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_start <= 1'b1;
                        state <= STATE_SPI_WAIT;
                    end
                end


                /*
                 * Wait for the SPI transaction.
                 */
                STATE_SPI_WAIT:
                begin
                    if (spi_done)
                    begin
                        sensor_id <= spi_read_data;
                        tx_index  <= 3'd0;

                        state <= STATE_UART_LOAD;
                    end
                end


                /*
                 * Prepare the next UART character.
                 *
                 * Output format:
                 *
                 * high nibble
                 * low nibble
                 * carriage return
                 * newline
                 */
                STATE_UART_LOAD:
                begin
                    case (tx_index)

                        3'd0:
                            uart_data <=
                                hex_to_ascii(sensor_id[7:4]);

                        3'd1:
                            uart_data <=
                                hex_to_ascii(sensor_id[3:0]);

                        3'd2:
                            uart_data <= 8'h0D;

                        3'd3:
                            uart_data <= 8'h0A;

                        default:
                            uart_data <= 8'h00;

                    endcase

                    state <= STATE_UART_PULSE;
                end


                /*
                 * Pulse UART enable.
                 */
                STATE_UART_PULSE:
                begin
                    if (!uart_busy)
                    begin
                        uart_start <= 1'b1;
                        state <= STATE_UART_WAIT_HIGH;
                    end
                end


                /*
                 * Confirm that transmission started.
                 */
                STATE_UART_WAIT_HIGH:
                begin
                    if (uart_busy)
                        state <= STATE_UART_WAIT_LOW;
                end


                /*
                 * Wait for transmission completion.
                 */
                STATE_UART_WAIT_LOW:
                begin
                    if (!uart_busy)
                    begin
                        if (tx_index == 3'd3)
                        begin
                            state <= STATE_DONE;
                        end
                        else
                        begin
                            tx_index <= tx_index + 1'b1;
                            state <= STATE_UART_LOAD;
                        end
                    end
                end


                /*
                 * Device ID has been transmitted.
                 */
                STATE_DONE:
                begin
                    state <= STATE_DONE;
                end


                default:
                begin
                    state <= STATE_STARTUP;
                end

            endcase
        end
    end

endmodule

`default_nettype wire
