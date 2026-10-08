// SPDX-License-Identifier: GPL-3.0-or-later
// GAL16V8 136090-1007 at 3F. Five registers (pins 13-17), clocked by pin 1.
// clk/ce stand for the rising edge of pin 1; reset is power-up only.
// Pins 12 and 18 are inputs on this chip.
module offtwall_gal_1007(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg [17:13] q;
    wire all = pin[2]&pin[3]&pin[4]&pin[5];
    wire sel = pin[12] | all;
    always @(posedge clk) begin
        if (reset) q <= 5'b11111;
        else if (ce) begin
            q[13] <= sel ? pin[6] : pin[2];
            q[14] <= sel ? pin[7] : pin[3];
            q[15] <= sel ? pin[8] : pin[4];
            q[16] <= sel ? pin[9] : pin[5];
            q[17] <= sel;
        end
    end
    assign value = {all, 1'b0, q, 1'b0};
    assign drive = {1'b1, 1'b0, {5{~pin[11]}}, 1'b0};
    wire unused = &{1'b0, pin};
endmodule
