// SPDX-License-Identifier: GPL-3.0-or-later
// GAL16V8 136090-1006 at 5F. Five registers (pins 12-16), clocked by pin 1.
// clk/ce stand for the rising edge of pin 1; reset is power-up only.
// Pins 18 and 19 are inputs on this chip.
module offtwall_gal_1006(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg [16:12] q;
    wire all = pin[2]&pin[3]&pin[4]&pin[5];
    always @(posedge clk) begin
        if (reset) q <= 5'b11111;
        else if (ce) begin
            q[12] <= ~all & ~pin[18];
            q[13] <= (pin[3]&pin[4]&pin[5]&pin[6]&~pin[19]) | (pin[6]&pin[18]&~pin[19]) | (~pin[2]&~pin[18]);
            q[14] <= (pin[2]&pin[4]&pin[5]&pin[7]&~pin[19]) | (pin[7]&pin[18]&~pin[19]) | (~pin[3]&~pin[18]);
            q[15] <= (pin[2]&pin[3]&pin[5]&pin[8]&~pin[19]) | (pin[8]&pin[18]&~pin[19]) | (~pin[4]&~pin[18]);
            q[16] <= (pin[2]&pin[3]&pin[4]&pin[9]&~pin[19]) | (pin[9]&pin[18]&~pin[19]) | (~pin[5]&~pin[18]);
        end
    end
    assign value = {2'b00, all, q};
    assign drive = {2'b00, 1'b1, {5{~pin[11]}}};
    wire unused = &{1'b0, pin};
endmodule
