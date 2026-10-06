// ============================================================
// LACOODA timing constraints - Sipeed Tang Primer 20K
//
// clk27 is the onboard 27 MHz oscillator that clocks the whole CPU.
// 27 MHz -> 37.037 ns period, 18.518 ns half period.
//
// Without this create_clock the analyzer only sees an inferred clock
// (WARN TA1132 'clk27' was determined to be a clock but was not created)
// and falls back to the synthesis Global Frequency as the period.
// ============================================================

create_clock -name clk27 -period 37.037 -waveform {0.000 18.518} [get_ports {clk27}]
