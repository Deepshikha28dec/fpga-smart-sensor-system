`default_nettype none

/*
 * 2:1 Multiplexer implemented using three Verilog
 * modelling styles:
 *
 *   1. Gate-level
 *   2. Dataflow
 *   3. Behavioral
 *
 * The modules are functionally equivalent:
 *
 *   select = 0 -> y = a
 *   select = 1 -> y = b
 */


/* Gate-level implementation */
module mux_gate_level (
    input  wire a,
    input  wire b,
    input  wire select,
    output wire y
);

    wire select_n;
    wire a_selected;
    wire b_selected;

    not (select_n, select);
    and (a_selected, a, select_n);
    and (b_selected, b, select);
    or  (y, a_selected, b_selected);

endmodule


/* Dataflow implementation */
module mux_dataflow (
    input  wire a,
    input  wire b,
    input  wire select,
    output wire y
);

    assign y = select ? b : a;

endmodule


/* Behavioral implementation */
module mux_behavioral (
    input  wire a,
    input  wire b,
    input  wire select,
    output reg  y
);

    always @(*)
    begin
        if (select)
            y = b;
        else
            y = a;
    end

endmodule

`default_nettype wire