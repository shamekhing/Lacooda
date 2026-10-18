// ============================================================
// LACOODA timing constraints - Sipeed Tang Primer 20K
//
// Timing-closure target: 100 MHz (10 ns). The board oscillator connected
// to clk27 is still 27 MHz; a PLL is required before hardware runs at 100 MHz.
//
// Without this create_clock the analyzer only sees an inferred clock
// (WARN TA1132 'clk27' was determined to be a clock but was not created)
// and falls back to the synthesis Global Frequency as the period.
// ============================================================

create_clock -name clk27 -period 10.000 -waveform {0.000 5.000} [get_ports {clk27}]
