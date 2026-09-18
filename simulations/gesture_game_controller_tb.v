`timescale 1ns/1ps
`default_nettype none

module gesture_game_controller_tb;

    /*
     * Faster frequencies for simulation.
     */
    localparam integer CLOCK_FREQ_HZ = 1_000_000;
    localparam integer SPI_FREQ_HZ   = 100_000;
    localparam integer UART_BAUD     = 100_000;

    localparam integer CLOCK_PERIOD_NS = 1000;
    localparam integer UART_BIT_NS =
        1_000_000_000 / UART_BAUD;


    reg clk;
    reg reset;
    reg spi_miso;

    wire spi_mosi;
    wire spi_clk;
    wire spi_cs_n;

    wire uart_tx;

    wire [15:0] y_axis;
    wire [15:0] z_axis;

    wire [7:0] gesture;
    wire       gesture_valid;


    /*
     * SPI peripheral model state.
     */
    integer spi_bit_count;
    integer sample_index;

    reg [7:0] command_byte;
    reg [7:0] response_byte;

    reg [7:0] received_uart_byte;


    /*
     * Device under test.
     */
    gesture_game_controller #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .SPI_FREQ_HZ   (SPI_FREQ_HZ),
        .UART_BAUD     (UART_BAUD)
    ) dut (
        .clk           (clk),
        .reset         (reset),

        .spi_miso      (spi_miso),
        .spi_mosi      (spi_mosi),
        .spi_clk       (spi_clk),
        .spi_cs_n      (spi_cs_n),

        .uart_tx       (uart_tx),

        .y_axis        (y_axis),
        .z_axis        (z_axis),

        .gesture       (gesture),
        .gesture_valid (gesture_valid)
    );


    /*
     * Clock generation.
     */
    initial
    begin
        clk = 1'b0;

        forever
            #(CLOCK_PERIOD_NS / 2)
            clk = ~clk;
    end


    /*
     * Return simulated ADXL345 register values.
     *
     * Sample 0 -> A
     * Sample 1 -> D
     * Sample 2 -> W
     * Sample 3 -> S
     *
     * Samples after that return a neutral position.
     */
    function [7:0] sensor_register_value;

        input [5:0] address;
        input integer sample;

        begin
            case (sample)

                /*
                 * LEFT:
                 * Y = 64
                 * Z = 125
                 */
                0:
                begin
                    case (address)
                        6'h34: sensor_register_value = 8'd64;
                        6'h35: sensor_register_value = 8'd0;
                        6'h36: sensor_register_value = 8'd125;
                        6'h37: sensor_register_value = 8'd0;
                        default:
                            sensor_register_value = 8'h00;
                    endcase
                end


                /*
                 * RIGHT:
                 * Y = 200
                 * Z = 125
                 */
                1:
                begin
                    case (address)
                        6'h34: sensor_register_value = 8'd200;
                        6'h35: sensor_register_value = 8'd0;
                        6'h36: sensor_register_value = 8'd125;
                        6'h37: sensor_register_value = 8'd0;
                        default:
                            sensor_register_value = 8'h00;
                    endcase
                end


                /*
                 * UP:
                 * Y = 125
                 * Z = 200
                 */
                2:
                begin
                    case (address)
                        6'h34: sensor_register_value = 8'd125;
                        6'h35: sensor_register_value = 8'd0;
                        6'h36: sensor_register_value = 8'd200;
                        6'h37: sensor_register_value = 8'd0;
                        default:
                            sensor_register_value = 8'h00;
                    endcase
                end


                /*
                 * DOWN:
                 * Y = 125
                 * Z = 50
                 */
                3:
                begin
                    case (address)
                        6'h34: sensor_register_value = 8'd125;
                        6'h35: sensor_register_value = 8'd0;
                        6'h36: sensor_register_value = 8'd50;
                        6'h37: sensor_register_value = 8'd0;
                        default:
                            sensor_register_value = 8'h00;
                    endcase
                end


                /*
                 * Neutral position.
                 */
                default:
                begin
                    case (address)
                        6'h34: sensor_register_value = 8'd125;
                        6'h35: sensor_register_value = 8'd0;
                        6'h36: sensor_register_value = 8'd125;
                        6'h37: sensor_register_value = 8'd0;
                        default:
                            sensor_register_value = 8'h00;
                    endcase
                end

            endcase
        end

    endfunction


    /*
     * Start of an SPI transaction.
     */
    always @(negedge spi_cs_n)
    begin
        spi_bit_count = 0;
        command_byte  = 8'h00;
        response_byte = 8'h00;
        spi_miso      = 1'b0;
    end


    /*
     * Capture the command byte sent by the FPGA.
     */
    always @(posedge spi_clk)
    begin
        if (!spi_cs_n)
        begin
            if (spi_bit_count < 8)
            begin
                command_byte =
                    {command_byte[6:0], spi_mosi};

                spi_bit_count =
                    spi_bit_count + 1;

                /*
                 * After the complete command byte has
                 * arrived, select the register response.
                 */
                if (spi_bit_count == 8)
                begin
                    if (command_byte[7])
                    begin
                        response_byte =
                            sensor_register_value(
                                command_byte[5:0],
                                sample_index
                            );
                    end
                end
            end
            else
            begin
                spi_bit_count =
                    spi_bit_count + 1;
            end
        end
    end


    /*
     * Drive MISO during the second byte of read
     * transactions.
     */
    always @(negedge spi_clk)
    begin
        if (!spi_cs_n)
        begin
            if ((spi_bit_count >= 8) &&
                (spi_bit_count < 16) &&
                command_byte[7])
            begin
                spi_miso <=
                    response_byte[
                        15 - spi_bit_count
                    ];
            end
            else
            begin
                spi_miso <= 1'b0;
            end
        end
    end


    /*
     * A complete Z-axis MSB read marks the end
     * of one complete Y/Z sample.
     */
    always @(posedge spi_cs_n)
    begin
        if ((command_byte[7] == 1'b1) &&
            (command_byte[5:0] == 6'h37))
        begin
            sample_index = sample_index + 1;
        end
    end


    /*
     * Decode one UART byte.
     */
    task receive_uart_byte;

        integer bit_index;

        begin
            /*
             * Wait for UART start bit.
             */
            @(negedge uart_tx);

            /*
             * Middle of start bit.
             */
            #(UART_BIT_NS / 2);

            if (uart_tx !== 1'b0)
            begin
                $display(
                    "ERROR: invalid UART start bit"
                );
            end


            /*
             * Move to center of data bit 0.
             */
            #(UART_BIT_NS);


            /*
             * UART transmits LSB first.
             */
            for (
                bit_index = 0;
                bit_index < 8;
                bit_index = bit_index + 1
            )
            begin
                received_uart_byte[bit_index] =
                    uart_tx;

                #(UART_BIT_NS);
            end


            /*
             * Stop bit.
             */
            if (uart_tx !== 1'b1)
            begin
                $display(
                    "ERROR: invalid UART stop bit"
                );
            end
        end

    endtask


    /*
     * Check a received gesture command.
     */
    task check_uart_command;

        input [7:0] expected;

        begin
            receive_uart_byte();

            if (received_uart_byte !== expected)
            begin
                $display(
                    "ERROR: expected '%c', received 0x%02h",
                    expected,
                    received_uart_byte
                );

                $fatal;
            end
            else
            begin
                $display(
                    "Gesture command received: %c",
                    received_uart_byte
                );
            end
        end

    endtask


    /*
     * Main test sequence.
     */
    initial
    begin
        $dumpfile(
            "simulations/gesture_game_controller.vcd"
        );

        $dumpvars(
            0,
            gesture_game_controller_tb
        );

        reset        = 1'b1;
        spi_miso     = 1'b0;
        sample_index = 0;

        repeat (5)
            @(posedge clk);

        reset = 1'b0;


        /*
         * Expected gesture sequence generated by
         * our simulated accelerometer samples.
         */
        check_uart_command("A");
        check_uart_command("D");
        check_uart_command("W");
        check_uart_command("S");


        $display("");
        $display(
            "Gesture game controller end-to-end test PASSED"
        );

        #20000;

        $finish;
    end

endmodule

`default_nettype wire
