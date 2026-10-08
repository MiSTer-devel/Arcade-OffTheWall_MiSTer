// SPDX-License-Identifier: GPL-3.0-or-later
// /DTACK: the 74F163 wait counter at 15J.
// Adapted from the Batman MiSTer core, whose schematic draws this circuit;
// this board's own sheet was never published.
// Copyright (C) 2026 the Batman MiSTer core authors.
//
// The counter runs on the processor clock. It is cleared between bus cycles,
// loads {/VPA, /VRWAIT, 1, /WAIT} while its QC output is low, then counts up;
// /DTACK is its carry out at 15. So:
//   /WAIT low            loads 14: one wait state
//   /VRWAIT low          loads 10 or 11: QC stays low, the cycle is held
//   /VPA low             held for good; the 68000 autovectors instead
//   nothing low          loads 15: no wait states
module offtwall_dtack(
    input  wire       clk,
    input  wire       ce_cpu,
    input  wire       as_n,
    input  wire       wait_n,
    input  wire       vrwait_n,
    input  wire       vpa_n,
    output wire       dtack_n,
    output wire [3:0] count
);
    reg [3:0] q;
    wire rco = (q == 4'hF);
    always @(posedge clk) begin
        if (ce_cpu) begin
            if (as_n)       q <= 4'd0;                               // /CLR
            else if (!q[2]) q <= {vpa_n, vrwait_n, 1'b1, wait_n};    // /LOAD = QC
            else if (!rco)  q <= q + 4'd1;                           // ENP = /DTACK
        end
    end
    assign dtack_n = !rco;
    assign count   = q;
endmodule
