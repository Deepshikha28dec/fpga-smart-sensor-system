`timescale 1ns/1ps
`default_nettype none

module adxl345_spi_tb;

    localparam integer CLOCK_FREQ_HZ = 12_000_000;
    localparam integer SPI_FREQ_HZ   = 1_000_000;

    reg clk;
    reg reset;

    reg start;
    reg read_write;

    reg [5:0] address;
    reg [7:0] write_data;

    reg spi_miso;

    wire [7:0] read_data;
    wire busy;
    wire done;

    wire spi_mosi;
    wire spi_clk;
    wire spi_cs_n;

    /*
     * Simulated ADXL345 response.
     */
    localparam [7:0] SENSOR_RESPONSE = 8'hA5;

    integer edge_count;

    reg [15:0] captured_mosi;


    adxl345_spi #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .SPI_FREQ_HZ   (SPI_FREQ_HZ)
    ) dut (
        .clk        (clk),
        .reset      (reset),

        .start      (start),
        .read_write (read_write),
        .address    (address),
        .write_data (write_data),

        .read_data  (read_data),
        .busy       (busy),
        .done       (done),

        .spi_miso   (spi_miso),
        .spi_mosi   (spi_mosi),
        .spi_clk    (spi_clk),
        .spi_cs_n   (spi_cs_n)
    );


    /*
     * 12 MHz system clock.
     */
    initial
    begin
        clk = 1'b0;

        forever
            #41.667 clk = ~clk;
    end


    /*
     * Reset peripheral-model state whenever
     * chip select becomes active.
     */
    always @(negedge spi_cs_n)
    begin
        edge_count    = 0;
        captured_mosi = 16'd0;
        spi_miso      = 1'b0;
    end


    /*
     * ADXL345 changes output data on falling SPI edges.
     *
     * First byte is the command phase.
     * Second byte returns SENSOR_RESPONSE.
     */
    always @(negedge spi_clk)
    begin
        if (!spi_cs_n)
        begin
            if (edge_count >= 8)
                spi_miso <=
                    SENSOR_RESPONSE[15 - edge_count];
            else
                spi_miso <= 1'b0;

            edge_count = edge_count + 1;
        end
    end


    /*
     * Capture MOSI on rising edges, like the peripheral.
     */
    always @(posedge spi_clk)
    begin
        if (!spi_cs_n)
        begin
            captured_mosi =
                {captured_mosi[14:0], spi_mosi};
        end
    end


    initial
    begin
        $dumpfile("adxl345_spi.vcd");
        $dumpvars(0, adxl345_spi_tb);

        reset      = 1'b1;
        start      = 1'b0;
        read_write = 1'b0;
        address    = 6'd0;
        write_data = 8'd0;
        spi_miso   = 1'b0;

        repeat (5)
            @(posedge clk);

        reset = 1'b0;

        /*
         * Read ADXL345 register 0x32.
         *
         * Expected command:
         *
         * R/W = 1
         * MB  = 0
         * address = 0x32
         *
         * command byte = 0xB2
         */
        @(posedge clk);

        address    <= 6'h32;
        read_write <= 1'b1;
        start      <= 1'b1;

        @(posedge clk);

        start <= 1'b0;

        wait (done);

        #1000;

        $display(
            "SPI transaction completed."
        );

        $display(
            "Command captured: 0x%02h",
            captured_mosi[15:8]
        );

        $display(
            "Data received:    0x%02h",
            read_data
        );

        if (captured_mosi[15:8] !== 8'hB2)
            $display("ERROR: incorrect command byte");

        if (read_data !== SENSOR_RESPONSE)
            $display("ERROR: incorrect read data");

        else
            $display("SPI read test PASSED");

        $finish;
    end

endmodule

`default_nettype wire
