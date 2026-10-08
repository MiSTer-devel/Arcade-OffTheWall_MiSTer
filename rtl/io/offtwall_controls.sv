// SPDX-License-Identifier: GPL-3.0-or-later
// Cabinet controls from MiSTer inputs: three stations, each one whirly-gig
// (an optical spinner on the station's UP and DN wires, counted by the LETA)
// or one 8-way joystick on the same wires, a START/ACTION button and the
// optional JAMMA start. Adapted from the Rampart MiSTer core's
// rampart_controls.sv (Copyright (C) 2026 RetroShrimp), whose sensitivity
// scaler follows the Blasteroids core, for one axis per station.
//
// joy_N is the hps_io joystick word: [0] right, [1] left, [2] down, [3] up,
// then the CONF_STR J1 list: [4] Action, [5] Start, [6] Coin.
//
// Whirly-gig panel: each station's rotation is the sum of every source, so
// no source selector is needed:
//   mouse    station 1, horizontal motion; the left button is Action
//   spinner  spinner_N: [7:0] signed delta, [8] toggles per update
//   paddle   the change of the absolute position; a jump of more than 64 in
//            one update (a paddle being plugged in) is ignored
//   stick    the left analog stick's X as a speed, with a small dead zone
//   d-pad    left and right, the speed of a full stick
// The sum is scaled by `sens` in eighths and paced by offtwall_whirly_axis.
// Joystick panel: the d-pad drives the four switches and nothing rotates.
//
// Outputs are board levels: a closed switch is 0. Station bytes are
// {UP, DN, LF, RT, ACTB, ACTA, FIRE, STRT}.
`timescale 1ns/1ps
module offtwall_controls #(
    parameter int unsigned SMOOTH_K   = 458182,   // see offtwall_whirly_axis
    parameter int unsigned RATE_CAP   = 29,
    parameter int          EDGE_STEP  = 2048,     // clk between quadrature edges
    parameter int unsigned STICK_TICK = 4096,     // clk per stick or d-pad step
    parameter int          STICK_DZ   = 12        // analog dead zone, of 127
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        joysticks,                 // 1 = joystick panel
    input  wire [31:0] joy_0, joy_1, joy_2,
    input  wire [15:0] ana_0, ana_1, ana_2,       // [7:0] X, signed
    input  wire  [8:0] spin_0, spin_1, spin_2,
    input  wire  [7:0] pad_0, pad_1, pad_2,
    input  wire [24:0] ps2_mouse,
    input  wire  [3:0] sens,                      // OSD index, 0 = 1x
    input  wire        invert,
    output wire  [7:0] p1_n, p2_n, p3_n,          // left, right, centre station
    output wire        coin1, coin2, service      // 1 = closed
);
    // ---- motion sources, clockwise positive ----
    reg ms_t;
    reg [2:0] sp_t;
    reg [7:0] pd_p0, pd_p1, pd_p2;
    always @(posedge clk) begin
        ms_t <= ps2_mouse[24];
        sp_t <= {spin_2[8], spin_1[8], spin_0[8]};
        pd_p0 <= pad_0; pd_p1 <= pad_1; pd_p2 <= pad_2;
    end
    wire signed [10:0] ms_x = ps2_mouse[24] != ms_t
                              ? 11'($signed({ps2_mouse[4], ps2_mouse[15:8]})) : 11'sd0;
    wire signed [10:0] sp_x0 = spin_0[8] != sp_t[0] ? 11'($signed(spin_0[7:0])) : 11'sd0;
    wire signed [10:0] sp_x1 = spin_1[8] != sp_t[1] ? 11'($signed(spin_1[7:0])) : 11'sd0;
    wire signed [10:0] sp_x2 = spin_2[8] != sp_t[2] ? 11'($signed(spin_2[7:0])) : 11'sd0;

    function automatic logic signed [10:0] pad_delta(input logic [7:0] now, input logic [7:0] prev);
        logic signed [9:0] d;
        d = $signed({2'b00, now}) - $signed({2'b00, prev});
        pad_delta = (d > 10'sd64 || d < -10'sd64) ? 11'sd0 : 11'(d);
    endfunction

    // ---- analog stick and d-pad as a speed ----
    localparam int TW = $clog2(STICK_TICK);
    reg [TW-1:0] tdiv;
    reg          tick;
    always @(posedge clk) begin
        if (reset) begin tdiv <= '0; tick <= 1'b0; end
        else begin
            tick <= tdiv == TW'(STICK_TICK - 1);
            tdiv <= tdiv == TW'(STICK_TICK - 1) ? '0 : tdiv + 1'b1;
        end
    end
    localparam logic signed [7:0] DZ = 8'(STICK_DZ);
    function automatic logic signed [7:0] speed(input logic [7:0] a, input logic neg, input logic pos);
        logic signed [7:0] s;
        s = $signed(a);
        if (s > DZ || s < -DZ) speed = (a == 8'h80) ? -8'sd127 : s;
        else if (pos)          speed = 8'sd127;
        else if (neg)          speed = -8'sd127;
        else                   speed = 8'sd0;
    endfunction

    // One count per 1024 speed units, taken every tick.
    logic signed [7:0]  vel  [0:2];
    logic signed [10:0] racc [0:2];
    logic signed [10:0] rate [0:2];
    logic signed [10:0] turn [0:2];
    logic signed [11:0] rsum [0:2];
    always_comb begin
        vel[0] = speed(ana_0[7:0], joy_0[1], joy_0[0]);
        vel[1] = speed(ana_1[7:0], joy_1[1], joy_1[0]);
        vel[2] = speed(ana_2[7:0], joy_2[1], joy_2[0]);
        turn[0] = ms_x + sp_x0 + pad_delta(pad_0, pd_p0) + rate[0];
        turn[1] = sp_x1 + pad_delta(pad_1, pd_p1) + rate[1];
        turn[2] = sp_x2 + pad_delta(pad_2, pd_p2) + rate[2];
        for (int i = 0; i < 3; i++) rsum[i] = 12'(racc[i]) + 12'(vel[i]);
    end
    always @(posedge clk) begin
        for (int i = 0; i < 3; i++) begin
            if (reset) begin
                racc[i] <= '0; rate[i] <= '0;
            end else if (tick) begin
                if (rsum[i] >= 12'sd1024)       begin racc[i] <= 11'(rsum[i] - 12'sd1024); rate[i] <=  11'sd1; end
                else if (rsum[i] <= -12'sd1024) begin racc[i] <= 11'(rsum[i] + 12'sd1024); rate[i] <= -11'sd1; end
                else                            begin racc[i] <= 11'(rsum[i]);             rate[i] <=  11'sd0; end
            end else begin
                rate[i] <= 11'sd0;
            end
        end
    end

    // ---- sensitivity in eighths; 1x first so a cleared OSD word is the default ----
    logic [5:0] mul8;
    always_comb begin
        case (sens)
            4'd0:  mul8 = 6'd8;
            4'd1:  mul8 = 6'd9;
            4'd2:  mul8 = 6'd10;
            4'd3:  mul8 = 6'd11;
            4'd4:  mul8 = 6'd12;
            4'd5:  mul8 = 6'd14;
            4'd6:  mul8 = 6'd16;
            4'd7:  mul8 = 6'd20;
            4'd8:  mul8 = 6'd24;
            4'd9:  mul8 = 6'd32;
            4'd10: mul8 = 6'd2;
            4'd11: mul8 = 6'd3;
            4'd12: mul8 = 6'd4;
            4'd13: mul8 = 6'd5;
            4'd14: mul8 = 6'd6;
            default: mul8 = 6'd7;
        endcase
    end
    logic signed [15:0] frac [0:2];
    logic signed [15:0] q    [0:2];
    logic signed [15:0] w    [0:2];
    logic signed [10:0] c    [0:2];
    logic signed [10:0] cnt  [0:2];
    always_comb begin
        for (int i = 0; i < 3; i++) begin
            q[i] = (16'(joysticks ? 11'sd0 : turn[i]) * $signed({10'd0, mul8})) + frac[i];
            w[i] = q[i] >>> 3;
            c[i] = (w[i] > 16'sd1023) ? 11'sd1023 : (w[i] < -16'sd1023) ? -11'sd1023 : 11'(w[i]);
        end
    end
    always @(posedge clk) begin
        for (int i = 0; i < 3; i++) begin
            if (reset) begin
                frac[i] <= '0; cnt[i] <= '0;
            end else begin
                frac[i] <= q[i] - (w[i] <<< 3);
                cnt[i]  <= invert ? -c[i] : c[i];
            end
        end
    end

    wire [2:0] q_clk, q_dir;
    genvar g;
    generate for (g = 0; g < 3; g++) begin : axis
        offtwall_whirly_axis #(.SMOOTH_K(SMOOTH_K), .RATE_CAP(RATE_CAP), .STEP(EDGE_STEP))
            u_axis(.clk(clk), .reset(reset), .delta(cnt[g]),
                   .q_clk(q_clk[g]), .q_dir(q_dir[g]));
    end endgenerate

    // ---- the station bytes ----
    function automatic logic [7:0] station(input logic [5:0] joy, input logic action,
                                           input logic clk_phase, input logic dir_phase);
        logic up, down, left, right;
        up    = joysticks ? joy[3] : clk_phase;
        down  = joysticks ? joy[2] : dir_phase;
        left  = joysticks && joy[1];
        right = joysticks && joy[0];
        station = ~{up, down, left, right, 2'b00, joy[4] | action, joy[5]};
    endfunction
    assign p1_n = station(joy_0[5:0], ps2_mouse[0], q_clk[0], q_dir[0]);
    assign p2_n = station(joy_1[5:0], 1'b0, q_clk[1], q_dir[1]);
    assign p3_n = station(joy_2[5:0], 1'b0, q_clk[2], q_dir[2]);
    assign coin1   = joy_0[6];
    assign coin2   = joy_1[6];
    assign service = joy_2[6];

    wire unused = &{1'b0, joy_0[31:7], joy_1[31:7], joy_2[31:7], ana_0[15:8], ana_1[15:8],
                    ana_2[15:8], ps2_mouse[23:16], ps2_mouse[7:5], ps2_mouse[3:1]};
endmodule
