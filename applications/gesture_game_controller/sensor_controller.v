`timescale 1ns/1ps
`default_nettype none

/*
 * ADXL345 Sensor Controller
 *
 * Configures the accelerometer and continuously acquires
 * raw Y- and Z-axis measurements through the reusable
 * adxl345_spi register interface.
 *
 * Original project configuration:
 *
 *   DATA_FORMAT (0x31) = 0x01
 *       -> +/- 4 g range
 *
 *   POWER_CTL   (0x2D) = 0x08
 *       -> measurement mode
 *
 * Axis registers:
 *
 *   Y-axis LSB = 0x34
 *   Y-axis MSB = 0x35
 *
 *   Z-axis LSB = 0x36
 *   Z-axis MSB = 0x37
 */

module sensor_controller (
    input  wire       clk,
    input  wire       reset,

    /*
     * Interface to adxl345_spi.
     */
    output reg        spi_start,
    output reg        spi_read_write,
    output reg [5:0]  spi_address,
    output reg [7:0]  spi_write_data,

    input  wire [7:0] spi_read_data,
    input  wire       spi_busy,
    input  wire       spi_done,

    /*
     * Reconstructed accelerometer values.
     */
    output reg [15:0] y_axis,
    output reg [15:0] z_axis,

    /*
     * One-clock pulse when a complete Y/Z sample
     * has been acquired.
     */
    output reg        sample_valid
);

    /*
     * ADXL345 register addresses.
     */
    localparam [5:0]
        REG_POWER_CTL   = 6'h2D,
        REG_DATA_FORMAT = 6'h31,

        REG_DATAY0      = 6'h34,
        REG_DATAY1      = 6'h35,

        REG_DATAZ0      = 6'h36,
        REG_DATAZ1      = 6'h37;


    /*
     * Configuration values preserved from the
     * original university implementation.
     */
    localparam [7:0]
        DATA_FORMAT_VALUE = 8'h01,
        POWER_CTL_VALUE   = 8'h08;


    /*
     * Controller states.
     */
    localparam [4:0]
        STATE_FORMAT_START = 5'd0,
        STATE_FORMAT_WAIT  = 5'd1,

        STATE_POWER_START  = 5'd2,
        STATE_POWER_WAIT   = 5'd3,

        STATE_Y_LSB_START  = 5'd4,
        STATE_Y_LSB_WAIT   = 5'd5,

        STATE_Y_MSB_START  = 5'd6,
        STATE_Y_MSB_WAIT   = 5'd7,

        STATE_Z_LSB_START  = 5'd8,
        STATE_Z_LSB_WAIT   = 5'd9,

        STATE_Z_MSB_START  = 5'd10,
        STATE_Z_MSB_WAIT   = 5'd11,

        STATE_SAMPLE_READY = 5'd12;


    reg [4:0] state;

    reg [7:0] y_lsb;
    reg [7:0] y_msb;

    reg [7:0] z_lsb;
    reg [7:0] z_msb;


    always @(posedge clk)
    begin
        if (reset)
        begin
            state          <= STATE_FORMAT_START;

            spi_start      <= 1'b0;
            spi_read_write <= 1'b0;
            spi_address    <= 6'd0;
            spi_write_data <= 8'd0;

            y_lsb          <= 8'd0;
            y_msb          <= 8'd0;
            z_lsb          <= 8'd0;
            z_msb          <= 8'd0;

            y_axis         <= 16'd0;
            z_axis         <= 16'd0;

            sample_valid   <= 1'b0;
        end

        else
        begin
            /*
             * These outputs are pulses unless explicitly
             * asserted in a state below.
             */
            spi_start    <= 1'b0;
            sample_valid <= 1'b0;


            case (state)

                /*
                 * Configure DATA_FORMAT register.
                 *
                 * Original project:
                 * 0x31 <- 0x01
                 */
                STATE_FORMAT_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_address    <= REG_DATA_FORMAT;
                        spi_read_write <= 1'b0;
                        spi_write_data <= DATA_FORMAT_VALUE;

                        spi_start <= 1'b1;
                        state     <= STATE_FORMAT_WAIT;
                    end
                end


                STATE_FORMAT_WAIT:
                begin
                    if (spi_done)
                        state <= STATE_POWER_START;
                end


                /*
                 * Enable ADXL345 measurement mode.
                 *
                 * 0x2D <- 0x08
                 */
                STATE_POWER_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_address    <= REG_POWER_CTL;
                        spi_read_write <= 1'b0;
                        spi_write_data <= POWER_CTL_VALUE;

                        spi_start <= 1'b1;
                        state     <= STATE_POWER_WAIT;
                    end
                end


                STATE_POWER_WAIT:
                begin
                    if (spi_done)
                        state <= STATE_Y_LSB_START;
                end


                /*
                 * Read Y-axis low byte.
                 */
                STATE_Y_LSB_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_address    <= REG_DATAY0;
                        spi_read_write <= 1'b1;
                        spi_write_data <= 8'h00;

                        spi_start <= 1'b1;
                        state     <= STATE_Y_LSB_WAIT;
                    end
                end


                STATE_Y_LSB_WAIT:
                begin
                    if (spi_done)
                    begin
                        y_lsb <= spi_read_data;
                        state <= STATE_Y_MSB_START;
                    end
                end


                /*
                 * Read Y-axis high byte.
                 */
                STATE_Y_MSB_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_address    <= REG_DATAY1;
                        spi_read_write <= 1'b1;
                        spi_write_data <= 8'h00;

                        spi_start <= 1'b1;
                        state     <= STATE_Y_MSB_WAIT;
                    end
                end


                STATE_Y_MSB_WAIT:
                begin
                    if (spi_done)
                    begin
                        y_msb <= spi_read_data;
                        state <= STATE_Z_LSB_START;
                    end
                end


                /*
                 * Read Z-axis low byte.
                 */
                STATE_Z_LSB_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_address    <= REG_DATAZ0;
                        spi_read_write <= 1'b1;
                        spi_write_data <= 8'h00;

                        spi_start <= 1'b1;
                        state     <= STATE_Z_LSB_WAIT;
                    end
                end


                STATE_Z_LSB_WAIT:
                begin
                    if (spi_done)
                    begin
                        z_lsb <= spi_read_data;
                        state <= STATE_Z_MSB_START;
                    end
                end


                /*
                 * Read Z-axis high byte.
                 */
                STATE_Z_MSB_START:
                begin
                    if (!spi_busy)
                    begin
                        spi_address    <= REG_DATAZ1;
                        spi_read_write <= 1'b1;
                        spi_write_data <= 8'h00;

                        spi_start <= 1'b1;
                        state     <= STATE_Z_MSB_WAIT;
                    end
                end


                STATE_Z_MSB_WAIT:
                begin
                    if (spi_done)
                    begin
                        z_msb <= spi_read_data;
                        state <= STATE_SAMPLE_READY;
                    end
                end


                /*
                 * Publish one complete Y/Z sample.
                 */
                STATE_SAMPLE_READY:
                begin
                    y_axis <= {y_msb, y_lsb};
                    z_axis <= {z_msb, z_lsb};

                    sample_valid <= 1'b1;

                    /*
                     * Continuously acquire another sample.
                     */
                    state <= STATE_Y_LSB_START;
                end


                default:
                begin
                    state <= STATE_FORMAT_START;
                end

            endcase
        end
    end

endmodule

`default_nettype wire