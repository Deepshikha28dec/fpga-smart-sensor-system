`timescale 1ns/1ps
`default_nettype none

/*
 * FPGA Gesture Game Controller
 *
 * Complete smart-sensor pipeline:
 *
 *   ADXL345
 *      |
 *      v
 *   SPI interface
 *      |
 *      v
 *   Sensor controller
 *      |
 *      v
 *   Gesture classifier
 *      |
 *      v
 *   UART transmitter
 *      |
 *      v
 *   Host PC / keyboard controller
 *
 * Recognized commands:
 *
 *   A -> left
 *   D -> right
 *   W -> up
 *   S -> down
 */

module gesture_game_controller #(
    parameter integer CLOCK_FREQ_HZ = 12_000_000,
    parameter integer SPI_FREQ_HZ   = 1_000_000,
    parameter integer UART_BAUD     = 9_600
) (
    input  wire clk,
    input  wire reset,

    /*
     * ADXL345 SPI signals.
     */
    input  wire spi_miso,
    output wire spi_mosi,
    output wire spi_clk,
    output wire spi_cs_n,

    /*
     * Host UART.
     */
    output wire uart_tx,

    /*
     * Optional debug outputs.
     */
    output wire [15:0] y_axis,
    output wire [15:0] z_axis,
    output wire [7:0]  gesture,
    output wire        gesture_valid
);

    /*
     * SPI control interface.
     */
    wire       spi_start;
    wire       spi_read_write;
    wire [5:0] spi_address;
    wire [7:0] spi_write_data;

    wire [7:0] spi_read_data;
    wire       spi_busy;
    wire       spi_done;


    /*
     * Sensor-controller outputs.
     */
    wire sample_valid;


    /*
     * UART control.
     */
    reg        uart_start;
    reg [7:0]  uart_data;

    wire uart_busy;


    /*
     * Track the previously transmitted gesture so the
     * same command is not continuously retransmitted
     * while the sensor remains in one orientation.
     */
    reg [7:0] previous_gesture;


    /*
     * ADXL345 SPI register interface.
     */
    adxl345_spi #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .SPI_FREQ_HZ   (SPI_FREQ_HZ)
    ) spi_inst (
        .clk        (clk),
        .reset      (reset),

        .start      (spi_start),
        .read_write (spi_read_write),
        .address    (spi_address),
        .write_data (spi_write_data),

        .read_data  (spi_read_data),
        .busy       (spi_busy),
        .done       (spi_done),

        .spi_miso   (spi_miso),
        .spi_mosi   (spi_mosi),
        .spi_clk    (spi_clk),
        .spi_cs_n   (spi_cs_n)
    );


    /*
     * Configure the ADXL345 and continuously acquire
     * Y- and Z-axis acceleration samples.
     */
    sensor_controller sensor_inst (
        .clk            (clk),
        .reset          (reset),

        .spi_start      (spi_start),
        .spi_read_write (spi_read_write),
        .spi_address    (spi_address),
        .spi_write_data (spi_write_data),

        .spi_read_data  (spi_read_data),
        .spi_busy       (spi_busy),
        .spi_done       (spi_done),

        .y_axis         (y_axis),
        .z_axis         (z_axis),

        .sample_valid   (sample_valid)
    );


    /*
     * Classify the accelerometer sample into a
     * keyboard command.
     */
    gesture_classifier classifier_inst (
        .y_axis        (y_axis),
        .z_axis        (z_axis),

        .gesture       (gesture),
        .gesture_valid (gesture_valid)
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
     * Send a recognized gesture once when a new
     * classification is observed.
     */
    always @(posedge clk)
    begin
        if (reset)
        begin
            uart_start       <= 1'b0;
            uart_data        <= 8'h00;
            previous_gesture <= 8'h00;
        end

        else
        begin
            /*
             * uart_start is a one-clock pulse.
             */
            uart_start <= 1'b0;

            if (sample_valid)
            begin
                /*
                 * A valid gesture is transmitted only if it
                 * differs from the previously transmitted one.
                 *
                 * This prevents continuously flooding the UART
                 * while the accelerometer remains in the same
                 * orientation.
                 */
                if (gesture_valid)
                begin
                    if ((gesture != previous_gesture) &&
                        !uart_busy)
                    begin
                        uart_data        <= gesture;
                        uart_start       <= 1'b1;
                        previous_gesture <= gesture;
                    end
                end

                /*
                 * No gesture resets the event history.
                 * The same gesture can therefore be generated
                 * again after returning to neutral.
                 */
                else
                begin
                    previous_gesture <= 8'h00;
                end
            end
        end
    end

endmodule

`default_nettype wire