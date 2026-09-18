`default_nettype none

/*
 * LED fading demonstration using an 8-bit PWM generator.
 *
 * Board clock:
 *     12 MHz
 *
 * PWM clock divider:
 *     12 MHz / 256 = 46.875 kHz
 *
 * 8-bit PWM frequency:
 *     46.875 kHz / 256 ≈ 183 Hz
 *
 * This PWM frequency is sufficiently above typical visible
 * flicker frequencies for an LED demonstration.
 *
 * The duty cycle is slowly increased from 0 to 255 and then
 * decreased back to 0, producing a continuous fade effect.
 */

module pwm_top (
    input  wire clk,
    input  wire reset,

    output wire led0,
    output wire led1,
    output wire led2,
    output wire led3,
    output wire led4,
    output wire led5,
    output wire led6,
    output wire led7
);

    /*
     * Clock-divider counters.
     */
    reg [7:0]  pwm_clk_divider;
    reg [18:0] fade_counter;

    /*
     * Current LED brightness.
     */
    reg [7:0] duty_cycle;

    /*
     * 1 = increasing brightness
     * 0 = decreasing brightness
     */
    reg fade_up;

    wire pwm_clk;
    wire pwm_signal;


    /*
     * Divide 12 MHz by 256.
     *
     * Using the MSB of an 8-bit free-running counter gives
     * approximately 46.875 kHz.
     */
    always @(posedge clk)
    begin
        if (reset)
            pwm_clk_divider <= 8'd0;
        else
            pwm_clk_divider <= pwm_clk_divider + 1'b1;
    end

    assign pwm_clk = pwm_clk_divider[7];


    /*
     * Slow fade controller.
     *
     * 2^19 / 12 MHz ≈ 43.7 ms between brightness changes.
     */
    always @(posedge clk)
    begin
        if (reset)
        begin
            fade_counter <= 19'd0;
            duty_cycle   <= 8'd0;
            fade_up      <= 1'b1;
        end
        else
        begin
            fade_counter <= fade_counter + 1'b1;

            if (fade_counter == 19'd0)
            begin
                if (fade_up)
                begin
                    if (duty_cycle == 8'hFF)
                    begin
                        fade_up    <= 1'b0;
                        duty_cycle <= duty_cycle - 1'b1;
                    end
                    else
                    begin
                        duty_cycle <= duty_cycle + 1'b1;
                    end
                end
                else
                begin
                    if (duty_cycle == 8'h00)
                    begin
                        fade_up    <= 1'b1;
                        duty_cycle <= duty_cycle + 1'b1;
                    end
                    else
                    begin
                        duty_cycle <= duty_cycle - 1'b1;
                    end
                end
            end
        end
    end


    pwm_module pwm_inst (
        .pwm_clk    (pwm_clk),
        .reset      (reset),
        .duty_cycle (duty_cycle),
        .pwm_out    (pwm_signal)
    );


    /*
     * All eight LEDs fade simultaneously.
     */
    assign led0 = pwm_signal;
    assign led1 = pwm_signal;
    assign led2 = pwm_signal;
    assign led3 = pwm_signal;
    assign led4 = pwm_signal;
    assign led5 = pwm_signal;
    assign led6 = pwm_signal;
    assign led7 = pwm_signal;

endmodule

`default_nettype wire