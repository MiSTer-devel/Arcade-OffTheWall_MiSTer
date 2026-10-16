// SPDX-License-Identifier: GPL-3.0-or-later
// CRT Adjust (MiSTer only): the OSD decode, the read-rate generator and the
// blanking glue around rmonic79's crt_adjust engine (crt_adjust.sv, from
// MiSTer-CRT-Adjust). Taken from the Blasteroids MiSTer core's
// blstroid_analog_adjust.sv, itself written from that project's
// examples/core_side_snippet.v, and re-derived here for an 8-clock pixel and
// this core's raster. See NOTICE.md.
// Copyright (C) 2026 RetroShrimp.
//
// Sits between offtwall_core and arcade_video, so the scandoubler, gamma and
// video_freak all see the adjusted picture and pixel enable. It never touches
// the core's own timing, so the game cannot observe it. Off is a bit-exact
// bypass.
//
// Controls, all two's complement, decoded with $signed():
//   H-Size      resamples the line so every pixel is wider or narrower by the
//               same amount, 1/64 of a pixel per step.
//   H-Position  moves the picture inside an unchanged HSync.
//   V-Shift     moves VSync by whole lines.
//
// H-Position mechanism (HPOS_MODE, picked at build time inside crt_adjust):
//   1 = content shift: the picture moves in the line buffer, HSync stays native.
//   0 = sync shift: HSync moves, the picture stays put.
// This core builds 1, as the analog adjust it replaces did. The line buffer's
// write pointer restarts on the HSync rise, and on this raster (456 pixels a
// line, active 0..335, HSync 375..406) that puts the picture at buffer
// positions 81..416: an 81-pixel lead-in and a 39-pixel run-out. A line holds
// 456 * 64 / (64 + H-Size) read ticks, so the right edge stays whole while
// 417 + H-Position fits in that: up to H-Position +39 at H-Size 0, and at
// H-Size +8 or more only with a negative H-Position (at +15, -48 or less).
// Past that the right edge is cut, as it was with the old stage. If a CRT
// shows a black block at the right edge, HPOS_MODE = 0 is the fallback.
//
// Read rate: period = 64 + H-Size units, where 64 units = CLK_PER_PIX clocks,
// and acc += 64/CLK_PER_PIX per clock. CLK_PER_PIX must be a power of two so
// the step is an exact integer. The top level sets H_TOTAL = 456,
// V_TOTAL = 262, CLK_PER_PIX = 8 (ce_7m).

module offtwall_analog_adjust #(
	parameter int H_TOTAL     = 456,   // ce_pix ticks per line
	parameter int V_TOTAL     = 262,   // lines per frame
	parameter int CLK_PER_PIX = 8,     // clk_sys cycles per ce_pix
	parameter int HPOS_MODE   = 1,     // 1 = content shift, 0 = sync shift
	parameter int AW          = 11     // line-buffer address bits: 456 px needs > 512 per bank
) (
	input  logic       clk,
	input  logic       ce_pix,

	// OSD
	input  logic       osd_on,         // CRT Adjust Off/On
	input  logic [4:0] osd_hsize,      // CRT H-Size        +15 / -16
	input  logic [6:0] osd_hpos,       // CRT H-Position    +63 / -64
	input  logic [5:0] osd_vshift,     // CRT V-Shift       +31 / -32

	input  logic [7:0] r_in, g_in, b_in,
	input  logic       hs_in, vs_in, hb_in, vb_in,

	output logic [7:0] r_out, g_out, b_out,
	output logic       hs_out, vs_out, hb_out, vb_out,
	output logic       ce_out
);

	localparam [7:0] ACC_STEP = 8'(64 / CLK_PER_PIX);

	// ---------------- OSD decode ----------------
	// Sampled at ce_pix so a menu change lands on a pixel boundary.
	logic              active;
	logic signed [4:0] hsize_s;
	logic signed [8:0] hpos_s;
	logic signed [5:0] vshift_s;

	always_ff @(posedge clk) if (ce_pix) begin
		active   <= osd_on;
		hsize_s  <= $signed(osd_hsize);
		hpos_s   <= 9'($signed(osd_hpos));
		vshift_s <= $signed(osd_vshift);
	end

	// ---------------- read-rate generator ----------------
	// Reset on the rise of the engine's hs_ref_out, never on the raw HSync, so
	// the write side, the engine's read counter and this rate restart together.
	wire  hs_ref;
	logic hs_ref_d;
	always_ff @(posedge clk) hs_ref_d <= hs_ref;
	wire  hs_ref_rise = hs_ref & ~hs_ref_d;

	wire  [7:0] rd_period = 8'd64 + {{3{hsize_s[4]}}, hsize_s};   // 48..79
	logic [7:0] rd_acc;
	wire        rd_tick = (rd_acc + ACC_STEP) >= rd_period;

	always_ff @(posedge clk) begin
		if      (hs_ref_rise) rd_acc <= 8'd0;
		else if (rd_tick)     rd_acc <= rd_acc + ACC_STEP - rd_period;
		else                  rd_acc <= rd_acc + ACC_STEP;
	end

	// When On the line buffer is always in use, even at H-Size 0.
	wire rd_ce = active ? rd_tick : ce_pix;

	// ---------------- the engine ----------------
	wire [7:0] str_r, str_g, str_b;
	wire       str_hs, str_vs, str_hb, str_vb;

	crt_adjust #(
		.VTOTAL    (V_TOTAL),
		.HTOTAL    (H_TOTAL),
		.HPOS_MODE (HPOS_MODE),
		.AW        (AW),
		.VB_LATE   (0)              // HSync follows the active pixels on this raster
	) u_crt_adjust (
		.clk        (clk),
		.pxl_cen    (ce_pix),
		.pxl2_cen   (rd_ce),
		.active     (active),
		.hsize      (hsize_s),      // unused by the engine; H-Size is the rate above
		.hoffset    (hpos_s),
		.voffset    (vshift_s),
		.r_in       (r_in), .g_in (g_in), .b_in (b_in),
		.hs_in      (hs_in),
		.vs_in      (vs_in),
		.hb_in      (hb_in | vb_in),
		.vb_in      (vb_in),
		.r_out      (str_r), .g_out (str_g), .b_out (str_b),
		.hs_out     (str_hs), .vs_out (str_vs),
		.hb_out     (str_hb), .vb_out (str_vb),
		.hs_ref_out (hs_ref)
	);

	// ---------------- vertical blank for arcade_video ----------------
	// arcade_video latches VBlank where HBlank falls. While On, the line being
	// emitted is the one written before the last HSync rise, and on this raster
	// that is the line whose own VBlank was sampled at that rise. str_vb is the
	// live input blank, one line ahead of the picture, and would hide the
	// bottom line. vb_read samples vb_in on the same edge as the engine's gate,
	// one flop, matching VB_LATE = 0.
	logic hs_ref_q;
	always_ff @(posedge clk) if (ce_pix) hs_ref_q <= hs_ref;
	wire  ref_line_tick = ce_pix & hs_ref & ~hs_ref_q;

	logic vb_read;
	always_ff @(posedge clk) if (ref_line_tick) vb_read <= vb_in;

	// Upstream's glue also builds a DE window pinned to the native active start
	// so the OSD does not slide with H-Position. It assumes the picture never
	// starts before the native one, which a negative H-Position does here (it is
	// how the right edge is kept on screen when H-Size enlarges), and the window
	// would then cut the left of the picture. So DE follows the picture, and the
	// OSD moves with H-Position.

	// ---------------- outputs ----------------
	assign r_out  = str_r;
	assign g_out  = str_g;
	assign b_out  = str_b;
	assign hs_out = str_hs;
	assign vs_out = str_vs;
	assign hb_out = str_hb;
	assign vb_out = active ? vb_read : str_vb;
	assign ce_out = rd_ce;

endmodule
