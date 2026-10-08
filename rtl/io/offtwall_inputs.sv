// SPDX-License-Identifier: GPL-3.0-or-later
// The I/O block at 260000: LS138 decoder 12J, player and status muxes,
// output latch 10J and the LETA at 16A. Adapted from the Relief Pitcher
// MiSTer core, which uses the same board.
//
// All switch inputs are as the muxes see them: 0 = closed.
module offtwall_inputs(
    input  wire        clk,
    input  wire        sysres_n,
    input  wire        as_n,
    input  wire        cio_n,
    input  wire  [6:1] a,
    input  wire [15:0] wdata,       // data bus on a write
    // players: {UP, DN, LF, RT, ACTB, ACTA, FIRE, STRT}
    input  wire  [7:0] p1_n, p2_n, p3_n, p4_n,
    input  wire  [3:0] service_n,   // {/SER-4 .. /SER-1}
    input  wire  [3:0] coin_n,      // {R, RC, LC, L}
    input  wire        vblank_n,
    input  wire        self_test_n,
    input  wire        audfull_n,
    input  wire        audirq_n,
    input  wire        vup_n,
    input  wire        vdn_n,
    input  wire        opt_sw,      // OP-S jumper: 1 = switches, 0 = optical
    input  wire        leta_fitted, // 0 on the joystick version of the board
    input  wire        ce_1h,       // LETA clock
    output wire        scom_rd_n,
    output wire        scom_wr_n,
    output wire        unlock_n,
    output wire [15:0] rdata,
    output wire [15:0] rdrive,      // which data bits the block is driving
    output reg   [3:0] coin_counter,   // {R, CR, CL, L}
    output reg         sndres_n,
    output reg         leta_res
);
    /* verilator lint_off UNUSEDSIGNAL */
    wire [7:0] sel_n = (!cio_n && !as_n) ? ~(8'd1 << a[6:4]) : 8'hFF;   // Y7 is unused
    wire unused = &{1'b0, a[3], wdata[15:9], wdata[7:5]};
    /* verilator lint_on UNUSEDSIGNAL */
    wire pl_sws_n = sel_n[0];
    wire status_n = sel_n[1];
    wire leta_n   = sel_n[2];
    assign scom_rd_n = sel_n[3];
    assign scom_wr_n = sel_n[4];
    wire latch_n  = sel_n[5];
    assign unlock_n  = sel_n[6];

    wire [15:0] players = a[1] ? {p2_n, p4_n} : {p1_n, p3_n};
    // Bit 0 of the first status byte has no net on this revision of the
    // drawing; an open LS257 input reads high.
    wire [7:0] status = a[1] ? {service_n, coin_n}
                             : {vblank_n, self_test_n, audfull_n, audirq_n,
                                vup_n, vdn_n, opt_sw, 1'b1};

    // LETA 16A. Channels 0 and 1 take the UP/DN lines of players 1 and 2;
    // channel 2 takes player 3's through the T3C/T3D jumpers; channel 3
    // would take player 4's. The second LETA socket (13A, high byte) is
    // never fitted.
    wire [7:0] leta_q;
    offtwall_leta u_leta(.clk(clk), .ck(ce_1h), .test(1'b0), .resol(leta_res),
        .ad(a[2:1]),
        .clks({p4_n[7], p3_n[7], p2_n[7], p1_n[7]}),
        .dirs({p4_n[6], p3_n[6], p2_n[6], p1_n[6]}),
        .dout(leta_q));

    assign rdata  = !pl_sws_n ? players :
                    !status_n ? {8'hFF, status} :
                    !leta_n   ? {8'hFF, leta_q} : 16'hFFFF;
    assign rdrive = !pl_sws_n ? 16'hFFFF :
                    !status_n ? 16'h00FF :
                    (!leta_n && leta_fitted) ? 16'h00FF : 16'h0000;

    // LS174 10J: clocked by the rising edge of /LATCH, cleared by /SYSRES.
    reg latch_q;
    always @(posedge clk) begin
        latch_q <= latch_n;
        if (!sysres_n) begin
            coin_counter <= 4'd0;
            sndres_n     <= 1'b0;
            leta_res     <= 1'b0;
            latch_q      <= 1'b1;
        end else if (!latch_q && latch_n) begin
            coin_counter <= {wdata[3], wdata[2], wdata[1], wdata[0]};
            sndres_n     <= wdata[4];
            leta_res     <= wdata[8];
        end
    end
endmodule
