// SPDX-License-Identifier: GPL-3.0-or-later
// Main address decode: the GAL at 15F and the F138 at 10F behind it.
//
// The GAL equations are the chip's own. Which signal is on which GAL pin, and
// the F138 wiring, are not on any published sheet; they follow the sister
// boards and the addresses the program uses.
module offtwall_decode(
    input  wire [21:15] a,
    input  wire        as_n,
    input  wire        hold_n,     // GAL pin 1: holds I/O cycles while low
    input  wire        vdtack_n,   // from the video system
    output wire        rom0_n,     // 000000-03FFFF
    output wire        romx_n,     // 000000-07FFFF
    output wire        e1_n,       // 140000-14FFFF (expansion, nothing fitted)
    output wire        wait_n,     // add one wait state
    output wire        vrwait_n,   // hold the cycle
    output wire        eeprom_n,   // 120000
    output wire        cio_n,      // 260000
    output wire        wdog_n,     // 2A0000
    output wire        video_n     // 3E0000-3FFFFF
);
    wire [19:1]  pin;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [19:12] value;     // pins 12 and 16 are constant
    wire [19:12] drive;
    /* verilator lint_on UNUSEDSIGNAL */
    assign pin[19:12] = 8'd0;
    assign pin[11]    = as_n;
    assign pin[10]    = 1'b0;
    assign pin[9]     = vdtack_n;
    assign pin[8:2]   = {a[15], a[16], a[17], a[18], a[19], a[20], a[21]};
    assign pin[1]     = hold_n;
    offtwall_gal_1003 u_gal(.clk(1'b0), .ce(1'b0), .reset(1'b0),
                            .pin(pin), .value(value), .drive(drive));
    assign rom0_n   = value[19];
    assign romx_n   = value[18];
    assign e1_n     = value[17];
    assign vrwait_n = value[15];
    wire   ioen_n   = value[14];
    assign wait_n   = value[13];

    // F138: enabled by /IOEN, selects on A19:A17.
    /* verilator lint_off UNUSEDSIGNAL */
    wire [7:0] y_n = ioen_n ? 8'hFF : ~(8'd1 << a[19:17]);
    /* verilator lint_on UNUSEDSIGNAL */
    assign eeprom_n = y_n[1];
    assign cio_n    = y_n[3];
    assign wdog_n   = y_n[5];
    assign video_n  = y_n[7];
endmodule
