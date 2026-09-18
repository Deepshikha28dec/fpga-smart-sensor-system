`default_nettype none

/*
 * 8-bit Pulse Width Modulation generator.
 *
 * The duty cycle controls the fraction of each 256-count
 * PWM period for which pwm_out remains high.
 *
 * duty_cycle =   0 -> approximately   0 %
 * duty_cycle = 128 -> approximately  50 %
 * duty_cycle = 255 -> approximately 100 %
 */

module pwm_module (
    input  wire       pwm_clk,
    input  wire       reset,
    input  wire [7:0] duty_cycle,
    output wire       pwm_out
);

    reg [7:0] pwm_counter;

    always @(posedge pwm_clk)
    begin
        if (reset)
            pwm_counter <= 8'd0;
        else
            pwm_counter <= pwm_counter + 1'b1;
    end

    assign pwm_out =
        (pwm_counter < duty_cycle) ? 1'b1 : 1'b0;

endmodule

`default_nettype wire