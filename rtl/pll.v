// The core's PLL, wrapped as the Altera PLL wizard would wrap it. The
// settings are in pll/pll_0002.v.
//
//   refclk   = CLK_50M, 50 MHz
//   outclk_0 = clk_sys, 57.272727 MHz (four times the board's 14.318 MHz crystal)
//   outclk_1 = the same clock delayed for the SDRAM_CLK pin

`timescale 1 ps / 1 ps
module pll (
		input  wire  refclk,   //  refclk.clk
		input  wire  rst,      //   reset.reset
		output wire  outclk_0, // outclk0.clk  clk_sys
		output wire  outclk_1, // outclk1.clk  SDRAM clock (phase-shifted)
		output wire  locked    //  locked.export
	);

	pll_0002 pll_inst (
		.refclk   (refclk),   //  refclk.clk
		.rst      (rst),      //   reset.reset
		.outclk_0 (outclk_0), // outclk0.clk
		.outclk_1 (outclk_1), // outclk1.clk
		.locked   (locked)    //  locked.export
	);

endmodule
