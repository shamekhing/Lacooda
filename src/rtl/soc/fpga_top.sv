`timescale 1ns/1ps

// ============================================================
// LACOODA Tang Primer 20K board wrapper
//
// cpu_system presents the wide simulation/debug observation ports
// (pc/instruction/alu_result are full words). Those cannot become physical
// pins on the GW2A-18C, so this wrapper is the synthesizable FPGA top and
// exposes only board-level I/O:
//
//      clk27   -> system clock (27 MHz onboard oscillator)
//      btn_n0  -> synchronous active-high reset (active-low button)
//      btn_n1  -> run enable (active-low button)
//      led0..5 -> retire_valid, illegal_instr, ALU parity, pc[2:0]
//
// cpu_system stays the unit under test in simulation; here it is driven by
// the board pins and its state is exposed through the LEDs so the optimizer
// cannot sweep the cpu_datapath away.
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
    cpu_pkg::instruction_t instruction;
    cpu_pkg::word_t        alu_result;

    logic retire_valid;
    logic illegal_instr;

    cpu_system u_cpu_system (
        .clk           (clk27),
        .rst           (rst),
        .run           (run),

        .pc            (pc),
        .instruction   (instruction),
        .retire_valid  (retire_valid),
        .illegal_instr (illegal_instr),
        .alu_result    (alu_result)
    );

    // ------------------------------------------------------------
    // Observation LEDs.
    //
    // retire_valid and the ALU result feed the visible signals, which keeps
    // the fetch/decode/execute path live through optimization.
    // ------------------------------------------------------------
    assign led0 = retire_valid;
    assign led1 = illegal_instr;
    assign led2 = ^alu_result;
    assign led3 = pc[0];
    assign led4 = pc[1];
    assign led5 = pc[2];

endmodule
