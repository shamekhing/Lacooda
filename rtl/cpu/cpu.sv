`timescale 1ns/1ps

// ============================================================
// LACOODA CPU — final CPU boundary
//
// Everything required to execute the Stage-7 ISA is inside this module:
//   - program counter and instruction fetch buffering
//   - decoder
//   - register file
//   - ALU/datapath
//   - status register
//   - branch unit
//   - LOAD/STORE transaction handling
//
// Memories and address routing are NOT inside the CPU. The CPU exposes two
// independent valid/ready master interfaces:
//
//   I-BUS : read-only instruction fetches
//   D-BUS : LOAD/STORE data transactions
//
// A request that has been started is held until ready. A fetched instruction
// is allowed to retire atomically even if run is deasserted meanwhile; run
// controls whether another instruction fetch is started afterward.
// ============================================================

module cpu (
    input logic clk,
    input logic rst,
    input logic run,

    // --------------------------------------------------------
    // Instruction-bus master interface (read-only).
    // --------------------------------------------------------
    output logic                  ibus_valid,
    output cpu_pkg::reg_t        ibus_address,
    input  logic                  ibus_ready,
    input  cpu_pkg::instruction_t ibus_read_data,

    // --------------------------------------------------------
    // Data-bus master interface.
    // dbus_write=0 -> LOAD/read
    // dbus_write=1 -> STORE/write
    // --------------------------------------------------------
    output logic           dbus_valid,
    output logic           dbus_write,
    output cpu_pkg::reg_t dbus_address,
    output cpu_pkg::data_memory_t dbus_write_data,
    input  logic           dbus_ready,
    input  cpu_pkg::data_memory_t dbus_read_data,

    // Observation outputs retained for simulation/debug.
    output cpu_pkg::reg_t        pc,
    output cpu_pkg::instruction_t instruction,
    output logic                  execution_valid,
    output logic                  illegal_instruction,
    output cpu_pkg::reg_t        result
);

    logic instruction_available;
    logic instruction_valid;
    logic core_enable;
    logic retire;

    cpu_pkg::reg_t operand_a;
    cpu_pkg::reg_t operand_b;

    alu_pkg::flags_t alu_flags;
    alu_pkg::flags_t status_flags;

    logic redirect;
    cpu_pkg::reg_t redirect_target;

    // A buffered instruction is already inside the CPU and is therefore
    // allowed to finish regardless of a later run deassertion. This also
    // guarantees that a waiting D-BUS request cannot be abandoned.
    assign core_enable = instruction_available && !rst;

    // Legal instructions retire when the core reports completion. Illegal
    // instructions have no architectural side effects but are consumed so
    // they cannot permanently wedge the fetch unit at one PC.
    assign retire =
        instruction_available &&
        !rst &&
        (execution_valid || illegal_instruction);

    // --------------------------------------------------------
    // FETCH / I-BUS
    // --------------------------------------------------------
    instruction_fetch u_instruction_fetch (
        .clk                   (clk),
        .rst                   (rst),
        .run                   (run),
        .retire                (retire),
        .redirect              (redirect),
        .redirect_target       (redirect_target),
        .ibus_valid            (ibus_valid),
        .ibus_address          (ibus_address),
        .ibus_ready            (ibus_ready),
        .ibus_read_data        (ibus_read_data),
        .pc                    (pc),
        .instruction           (instruction),
        .instruction_available (instruction_available)
    );

    // --------------------------------------------------------
    // EXECUTION CORE / D-BUS
    // --------------------------------------------------------
    cpu_core u_cpu_core (
        .clk                 (clk),
        .rst                 (rst),

        .instruction_enable  (core_enable),
        .instruction         (instruction),

        // ADC/SBC retain the existing fixed carry input behavior.
        .carry_in            (1'b0),

        .dbus_ready           (dbus_ready),
        .dbus_read_data       (dbus_read_data),

        .instruction_valid   (instruction_valid),
        .illegal_instruction (illegal_instruction),
        .execution_valid     (execution_valid),

        .redirect            (redirect),
        .redirect_target     (redirect_target),

        .dbus_valid           (dbus_valid),
        .dbus_write           (dbus_write),
        .dbus_address         (dbus_address),
        .dbus_write_data      (dbus_write_data),

        .operand_a           (operand_a),
        .operand_b           (operand_b),
        .result              (result),

        .alu_flags           (alu_flags),
        .status_flags        (status_flags)
    );

endmodule
