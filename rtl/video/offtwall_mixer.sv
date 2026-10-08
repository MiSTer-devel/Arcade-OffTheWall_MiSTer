// SPDX-License-Identifier: GPL-3.0-or-later
// Colour RAM address from the two mixer GALs. 5F (136090-1006) chooses the
// pen and 3F (136090-1007) the colour: the motion object wins wherever the
// line buffer holds one. The wiring follows the Relief Pitcher MiSTer core's
// relief_mixer.sv for the same sockets; it is not on any published sheet.
// The line buffer's pen reaches 5F active low, and an empty pixel reads as
// all ones on both nibbles, so 3F pin 19 (colour all ones) sends 5F to the
// playfield. A motion object of colour 15 therefore never shows.
// Colour RAM address: 200 + playfield colour * 16 + pen, or
// 100 + motion object colour * 16 + pen.
module offtwall_mixer(
    input  wire        clk,
    input  wire        reset,
    input  wire        ce,
    input  wire  [7:0] mo,          // line buffer: colour, pen; pen 0 is empty
    input  wire  [3:0] pf_pen,
    input  wire  [3:0] pf_colour,
    output wire [10:0] index
);
    wire [7:0] lb = mo[3:0] == 4'd0 ? 8'hFF : {mo[7:4], ~mo[3:0]};

    wire [19:12] q_3f, q_5f, drive_3f, drive_5f;
    // Pin vectors run from 19 down to 1; unconnected pins are tied low.
    wire [19:1] pin_5f = {1'b0, q_3f[19], 8'd0, pf_pen, lb[3:0], 1'b0};
    wire [19:1] pin_3f = {7'd0, q_5f[17], 2'd0, pf_colour, lb[7:4], 1'b0};

    offtwall_gal_1007 u_3f(.clk(clk), .ce(ce), .reset(reset), .pin(pin_3f),
        .value(q_3f), .drive(drive_3f));
    offtwall_gal_1006 u_5f(.clk(clk), .ce(ce), .reset(reset), .pin(pin_5f),
        .value(q_5f), .drive(drive_5f));

    assign index = {1'b0, q_3f[17], q_5f[12], q_3f[16:13], q_5f[16:13]};
    wire unused = &{1'b0, q_3f[18], q_3f[12], q_5f[19:18], drive_3f, drive_5f};
endmodule
