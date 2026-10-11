`timescale 1ns/1ps

// ============================================================
// LACOODA Tang Primer 20K board wrapper
//
// This wrapper is the synthesizable FPGA top and exposes board-level I/O:
//
//      clk27   -> system clock (27 MHz onboard oscillator)
//      btn_n0  -> synchronous active-high reset (active-low button)
//      btn_n1  -> run enable (active-low button)
//      led0..1 -> retire_valid, illegal_instr
//      led2..5 -> reserved
//
// system stays the unit under test in simulation; here it is driven by
// the board pins and retirement status is exposed through the LEDs.
// ============================================================

module fpga_top (
    input  logic clk27,

    input  logic btn_n0,
    input  logic btn_n1,

    output logic led0,
    output logic led1,
    output logic led2,
    output logic led3,
    output logic led4,
    output logic led5
);

    // ------------------------------------------------------------
    // Button conditioning.
    //
    // The board buttons are asynchronous and active-low; the CPU reset is
    // synchronous and active-high. Two flops de-metastabilize the pins and
    // flip the polarity in one place.
    // ------------------------------------------------------------
    logic [1:0] rst_sync;
    logic [1:0] run_sync;

    always_ff @(posedge clk27) begin
        rst_sync <= {rst_sync[0], ~btn_n0};
        run_sync <= {run_sync[0], ~btn_n1};
    end

    logic rst;
    logic run;

    assign rst = rst_sync[1];
    assign run = run_sync[1];

    // ------------------------------------------------------------
    // CPU system
    // ------------------------------------------------------------
    cpu_pkg::word_t        pc;
    logic retire_valid;
    logic illegal_instr;

    system u_system (
        .clk           (clk27),
        .rst           (rst),
        .run           (run),

        .pc            (pc),
        .retire_valid  (retire_valid),
        .illegal_instr (illegal_instr)
    );

    // ------------------------------------------------------------
    // Observation LEDs.
    //
    // Retirement status is visible; the remaining LEDs are reserved.
    // ------------------------------------------------------------
    assign led0 = retire_valid;
    assign led1 = illegal_instr;
    assign led2 = 1'b0; // ALU parity not yet implemented
    assign led3 = 1'b0; // ALU parity not yet implemented
    assign led4 = 1'b0; // ALU parity not yet implemented
    assign led5 = 1'b0; // ALU parity not yet implemented

endmodule
