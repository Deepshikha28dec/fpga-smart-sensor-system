`timescale 1ns/1ps
`default_nettype none

module accelerometer_reader_tb;

    /*
     * Faster simulation parameters.
     */
    localparam integer CLOCK_FREQ_HZ = 1_000_000;
    localparam integer SPI_FREQ_HZ   = 100_000;
    localparam integer UART_BAUD     = 100_000;

    localparam integer CLOCK_PERIOD_NS = 1000;
    localparam integer UART_BIT_NS =
        1_000_000_000 / UART_BAUD;

    localparam [7:0] ADXL345_ID = 8'hE5;


    reg clk;
    reg reset;
    reg spi_miso;

    wire spi_mosi;
    wire spi_clk;
    wire spi_cs_n;

    wire uart_tx;

    wire [7:0] sensor_id;


    /*
     * Simulated SPI peripheral state.
     */
    integer spi_edge_count;

    reg [7:0] received_uart_byte;


    accelerometer_reader #(
        .CLOCK_FREQ_HZ  (CLOCK_FREQ_HZ),
        .SPI_FREQ_HZ    (SPI_FREQ_HZ),
        .UART_BAUD      (UART_BAUD),
        .STARTUP_CYCLES (10)
    ) dut (
        .clk       (clk),
        .reset     (reset),

        .spi_miso  (spi_miso),
        .spi_mosi  (spi_mosi),
        .spi_clk   (spi_clk),
        .spi_cs_n  (spi_cs_n),

        .uart_tx   (uart_tx),

        .sensor_id (sensor_id)
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
     * Reset SPI model whenever chip select becomes active.
     */
    always @(negedge spi_cs_n)
    begin
        spi_edge_count = 0;
        spi_miso = 1'b0;
    end


    /*
     * Simulated ADXL345 SPI response.
     *
     * First 8 clocks:
     *   command byte received from FPGA
     *
     * Second 8 clocks:
     *   return device ID 0xE5
     */
    always @(negedge spi_clk)
    begin
        if (!spi_cs_n)
        begin
            if (spi_edge_count >= 8)
            begin
                spi_miso <=
                    ADXL345_ID[15 - spi_edge_count];
            end
            else
            begin
                spi_miso <= 1'b0;
            end

            spi_edge_count = spi_edge_count + 1;
        end
    end


    /*
     * Decode one UART byte directly from uart_tx.
     */
    task receive_uart_byte;

        integer bit_index;

        begin
            /*
             * Wait for falling edge of start bit.
             */
            @(negedge uart_tx);

            /*
             * Move to the middle of the start bit.
             */
            #(UART_BIT_NS / 2);

            if (uart_tx !== 1'b0)
            begin
                $display("ERROR: Invalid UART start bit");
            end

            /*
             * Move to center of data bit 0.
             */
            #(UART_BIT_NS);

            for (bit_index = 0;
                 bit_index < 8;
                 bit_index = bit_index + 1)
            begin
                received_uart_byte[bit_index] =
                    uart_tx;

                #(UART_BIT_NS);
            end

            /*
             * Stop bit should be HIGH.
             */
            if (uart_tx !== 1'b1)
            begin
                $display("ERROR: Invalid UART stop bit");
            end
        end

    endtask


    initial
    begin
        $dumpfile(
            "simulations/accelerometer_reader.vcd"
        );

        $dumpvars(
            0,
            accelerometer_reader_tb
        );

        reset     = 1'b1;
        spi_miso  = 1'b0;

        repeat (5)
            @(posedge clk);

        reset = 1'b0;


        /*
         * Wait until FPGA has successfully read
         * the ADXL345 device ID.
         */
        wait (sensor_id == ADXL345_ID);

        $display(
            "ADXL345 Device ID received: 0x%02h",
            sensor_id
        );


        /*
         * Expected UART output:
         *
         * E
         * 5
         * carriage return
         * newline
         */

        receive_uart_byte();

        if (received_uart_byte !== "E")
        begin
            $display(
                "ERROR: Expected 'E', received 0x%02h",
                received_uart_byte
            );
        end
        else
        begin
            $display("UART byte 1: E");
        end


        receive_uart_byte();

        if (received_uart_byte !== "5")
        begin
            $display(
                "ERROR: Expected '5', received 0x%02h",
                received_uart_byte
            );
        end
        else
        begin
            $display("UART byte 2: 5");
        end


        receive_uart_byte();

        if (received_uart_byte !== 8'h0D)
        begin
            $display(
                "ERROR: Expected carriage return"
            );
        end
        else
        begin
            $display("UART byte 3: CR");
        end


        receive_uart_byte();

        if (received_uart_byte !== 8'h0A)
        begin
            $display(
                "ERROR: Expected newline"
            );
        end
        else
        begin
            $display("UART byte 4: LF");
        end


        $display("");
        $display(
            "End-to-end accelerometer interface test PASSED"
        );

        #10000;

        $finish;
    end

endmodule

`default_nettype wire
