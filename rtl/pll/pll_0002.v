`timescale 1ns/10ps
//============================================================================
//  The core's PLL: an Altera PLL (Cyclone V fPLL) set up by hand. Taken from
//  the Relief Pitcher MiSTer core, which runs the same clock.
//
//  refclk = CLK_50M, 50 MHz.
//
//  outclk_0 = clk_sys, 57.272727 MHz: VCO 50 x 63 / 5 = 630 MHz, divided by
//      11. That is four times the board's 14.318181 MHz crystal, within
//      0.06 ppm, and every rate in the core is a whole division of it:
//        /4 = 14.318 MHz (video timing, 68000)   /8 = 7.159 MHz (pixel clock)
//        /16 = 3.580 MHz (YM2151)                /32 = 1.790 MHz (6502)
//
//  outclk_1 = SDRAM_CLK, the same 57.272727 MHz delayed by 13095 ps (tap 66
//      of 88, 270 degrees), so that SDRAM read data is captured in the
//      middle of its valid window. The value is the centre of the good
//      window, 225 to 315 degrees, found by a sweep on real hardware at this
//      clock. Quartus accepts only whole VCO/8 steps (198.4 ps) here.
//============================================================================
module  pll_0002(

	// interface 'refclk'
	input wire refclk,

	// interface 'reset'
	input wire rst,

	// interface 'outclk0'  -- clk_sys, 57.272727 MHz
	output wire outclk_0,

	// interface 'outclk1'  -- SDRAM_CLK, 57.272727 MHz, delayed 13095 ps
	output wire outclk_1,

	// interface 'locked'
	output wire locked
);

	altera_pll #(
		.fractional_vco_multiplier("false"),
		.reference_clock_frequency("50.0 MHz"),
		.operation_mode("direct"),
		.number_of_clocks(2),
		.output_clock_frequency0("57.272727 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.output_clock_frequency1("57.272727 MHz"),
		.phase_shift1("13095 ps"),
		.duty_cycle1(50),
		.output_clock_frequency2("0 MHz"),
		.phase_shift2("0 ps"),
		.duty_cycle2(50),
		.output_clock_frequency3("0 MHz"),
		.phase_shift3("0 ps"),
		.duty_cycle3(50),
		.output_clock_frequency4("0 MHz"),
		.phase_shift4("0 ps"),
		.duty_cycle4(50),
		.output_clock_frequency5("0 MHz"),
		.phase_shift5("0 ps"),
		.duty_cycle5(50),
		.output_clock_frequency6("0 MHz"),
		.phase_shift6("0 ps"),
		.duty_cycle6(50),
		.output_clock_frequency7("0 MHz"),
		.phase_shift7("0 ps"),
		.duty_cycle7(50),
		.output_clock_frequency8("0 MHz"),
		.phase_shift8("0 ps"),
		.duty_cycle8(50),
		.output_clock_frequency9("0 MHz"),
		.phase_shift9("0 ps"),
		.duty_cycle9(50),
		.output_clock_frequency10("0 MHz"),
		.phase_shift10("0 ps"),
		.duty_cycle10(50),
		.output_clock_frequency11("0 MHz"),
		.phase_shift11("0 ps"),
		.duty_cycle11(50),
		.output_clock_frequency12("0 MHz"),
		.phase_shift12("0 ps"),
		.duty_cycle12(50),
		.output_clock_frequency13("0 MHz"),
		.phase_shift13("0 ps"),
		.duty_cycle13(50),
		.output_clock_frequency14("0 MHz"),
		.phase_shift14("0 ps"),
		.duty_cycle14(50),
		.output_clock_frequency15("0 MHz"),
		.phase_shift15("0 ps"),
		.duty_cycle15(50),
		.output_clock_frequency16("0 MHz"),
		.phase_shift16("0 ps"),
		.duty_cycle16(50),
		.output_clock_frequency17("0 MHz"),
		.phase_shift17("0 ps"),
		.duty_cycle17(50),
		.pll_type("General"),
		.pll_subtype("General")
	) altera_pll_i (
		.rst	(rst),
		.outclk	({outclk_1, outclk_0}),
		.locked	(locked),
		.fboutclk	( ),
		.fbclk	(1'b0),
		.refclk	(refclk)
	);
endmodule
