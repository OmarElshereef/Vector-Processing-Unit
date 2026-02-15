
module Mux_4x1 (
    input wire a,
    input wire b,
    input wire c,
    input wire d,
    input wire [1:0] sel,
    output wire y
);
    wire y0, y1;

    // First level of multiplexing
    Mux_2x1 mux0 (
        .a(a),
        .b(b),
        .sel(sel[0]),
        .y(y0)
    );

    Mux_2x1 mux1 (
        .a(c),
        .b(d),
        .sel(sel[0]),
        .y(y1)
    );

    // Second level of multiplexing
    Mux_2x1 mux2 (
        .a(y0),
        .b(y1),
        .sel(sel[1]),
        .y(y)
    );
    
endmodule