`timescale 1ns/1ps
`default_nettype none

/*
 * Gesture Classifier
 *
 * Converts accelerometer Y/Z-axis measurements into
 * ASCII movement commands for the host-side game controller.
 *
 * The threshold ranges preserve the behaviour of the
 * original university implementation:
 *
 *   Y:  20 < value < 120  -> 'A' (left)
 *   Y: 130 < value < 230  -> 'D' (right)
 *   Z: value > 130        -> 'W' (up)
 *   Z: value < 120        -> 'S' (down)
 *
 * Y-axis gestures have priority over Z-axis gestures,
 * matching the original project behaviour.
 */

module gesture_classifier (
    input  wire [15:0] y_axis,
    input  wire [15:0] z_axis,

    output reg  [7:0]  gesture,
    output reg         gesture_valid
);

    /*
     * The original implementation classified gestures
     * using the lower byte of each 16-bit sensor value.
     */
    wire [7:0] y_value = y_axis[7:0];
    wire [7:0] z_value = z_axis[7:0];


    localparam [7:0]
        KEY_LEFT  = 8'h41,   // ASCII 'A'
        KEY_RIGHT = 8'h44,   // ASCII 'D'
        KEY_UP    = 8'h57,   // ASCII 'W'
        KEY_DOWN  = 8'h53;   // ASCII 'S'


    always @(*)
    begin
        /*
         * Default: no recognized gesture.
         */
        gesture       = 8'h00;
        gesture_valid = 1'b0;


        /*
         * Left gesture.
         */
        if ((y_value > 8'd20) &&
            (y_value < 8'd120))
        begin
            gesture       = KEY_LEFT;
            gesture_valid = 1'b1;
        end

        /*
         * Right gesture.
         */
        else if ((y_value > 8'd130) &&
                 (y_value < 8'd230))
        begin
            gesture       = KEY_RIGHT;
            gesture_valid = 1'b1;
        end

        /*
         * Up gesture.
         */
        else if (z_value > 8'd130)
        begin
            gesture       = KEY_UP;
            gesture_valid = 1'b1;
        end

        /*
         * Down gesture.
         */
        else if (z_value < 8'd120)
        begin
            gesture       = KEY_DOWN;
            gesture_valid = 1'b1;
        end
    end

endmodule

`default_nettype wire