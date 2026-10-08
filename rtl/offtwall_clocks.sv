// SPDX-License-Identifier: GPL-3.0-or-later
// Clock enables for the one 57.272727 MHz system clock (4 x the board's
// 14.318 MHz crystal). Each enable is high for one clk_sys in its period.
module offtwall_clocks(
    input  wire clk_sys,
    input  wire reset,
    output wire ce_14m,   // crystal rate
    output wire ce_7m,    // pixel clock
    output wire ce_3m58,  // "1H": sound board master clock and LETA clock
    output wire ce_1m79   // sound CPU
);
    reg [4:0] phase;
    always @(posedge clk_sys) begin
        if (reset) phase <= 5'd0;
        else       phase <= phase + 5'd1;
    end
    assign ce_14m  = !reset && phase[1:0] == 2'd3;
    assign ce_7m   = !reset && phase[2:0] == 3'd7;
    assign ce_3m58 = !reset && phase[3:0] == 4'd7;
    assign ce_1m79 = !reset && phase      == 5'd7;
endmodule
