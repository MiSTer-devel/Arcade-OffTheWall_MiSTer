// SPDX-License-Identifier: GPL-3.0-or-later
// Program ROM bank device, 136090-1001 (a GAL6001 next to the program ROMs).
//
// The real chip has never been read out. This is a reconstruction from what
// the two program ROM sets require of it; it is exact for every ROM access
// the game makes, but it is not the chip's own equations.
//
// The top 32 KB of the program ROM (038000-03FFFF) is four 8 KB chunks. The
// chip adds a 2-bit bank to ROM address lines A14:A13 inside that window.
// It watches ROM bus cycles only, and counts how many in a row address the
// level table (037EC2-037F43):
//   - one table cycle on its own selects the bank from the table address,
//     bank = A2:A1 - 1, when the next ROM cycle arrives;
//   - two in a row do nothing;
//   - the third in a row steps the bank by one.
module offtwall_sloop(
    input  wire        clk,
    input  wire        reset,      // power-up only
    input  wire        rom_cycle,  // one clk pulse at the start of each ROM bus cycle
    input  wire [17:1] a,          // 68000 address of that cycle
    output wire [14:13] ra         // address lines A14:A13 as the ROMs see them
);
    reg [1:0] bank;
    reg [1:0] run;    // table cycles in a row so far, stops at 3
    reg [1:0] value;  // the bank a single table cycle would select

    wire table_hit = (a >= 17'h1BF61) && (a < 17'h1BFA2);  // 037EC2-037F43
    wire window    = (a[17:15] == 3'b111);

    always @(posedge clk) begin
        if (reset) begin
            bank  <= 2'd0;
            run   <= 2'd0;
            value <= 2'd0;
        end else if (rom_cycle) begin
            if (table_hit) begin
                if (run == 2'd0) value <= a[2:1] - 2'd1;
                if (run == 2'd2) bank  <= bank + 2'd1;
                if (run != 2'd3) run   <= run + 2'd1;
            end else begin
                if (run == 2'd1) bank <= value;
                run <= 2'd0;
            end
        end
    end

    assign ra = window ? (a[14:13] + bank) : a[14:13];
endmodule
