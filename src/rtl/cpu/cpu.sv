`timescale 1ns/1ps

// ============================================================
// LACOODA CPU — final CPU boundary
//
// Everything required to execute the ISA is inside this module:
//   - program counter and instruction fetch buffering
//   - cpu_decoder
//   - register file
//   - ALU/cpu_datapath
//   - status register
//   - branch unit
//   - LOAD/STORE transaction handling
//
// Memories and address routing are NOT inside the CPU. The CPU exposes two
// independent typed valid/ready master interfaces:
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

    // Instruction-bus master interface (read-only).
    output bus_pkg::bus_req_s instr_req,
    input  bus_pkg::bus_rsp_s instr_rsp,

    // Data-bus master interface.
    // dbus_write=0 -> LOAD/read
    // dbus_write=1 -> STORE/write
    output bus_pkg::bus_req_s data_req,
    input  bus_pkg::bus_rsp_s data_rsp,

    // Observation outputs retained for simulation/debug.
    output cpu_pkg::word_t        pc,
    output cpu_pkg::instruction_t instruction,
    output logic                  retire_valid,
    output logic                  illegal_instr,
    output cpu_pkg::word_t        alu_result
);

    logic instruction_available;
    logic decode_valid;
    logic core_enable;
    logic retire;

    cpu_pkg::word_t immediate_word;

    cpu_pkg::word_t operand_a;
    cpu_pkg::word_t operand_b;

    cpu_pkg::flags_s  flags;
    cpu_pkg::status_t status;

    logic redirect;
    cpu_pkg::word_t redirect_target;

    logic dbus_valid;
    logic dbus_write;
    cpu_pkg::word_t dbus_addr;
    cpu_pkg::word_t dbus_wdata;

    // The execution core retains its scalar control ports internally;
    // the CPU boundary presents the data side as a typed bus value.
    assign data_req.valid = dbus_valid;
    assign data_req.op    = dbus_write ? bus_pkg::BUS_WRITE : bus_pkg::BUS_READ;
    assign data_req.addr  = dbus_addr;
    assign data_req.wdata = dbus_wdata;

    // A buffered instruction is already inside the CPU and is therefore
    // allowed to finish regardless of a later run deassertion. This also
    // guarantees that a waiting D-BUS request cannot be abandoned.
    assign core_enable = instruction_available && !rst;

    // Legal instructions retire when the core reports completion. Illegal
    // instructions have no architectural side effects but are consumed so
    // they cannot permanently wedge the fetch unit at one pc.
    assign retire =
        instruction_available &&
        !rst &&
        (retire_valid || illegal_instr);

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
        .ibus_req              (instr_req),
        .ibus_rsp              (instr_rsp),
        .pc                    (pc),
        .instruction           (instruction),
        .immediate_word        (immediate_word),
        .instruction_available (instruction_available)
    );

    // --------------------------------------------------------
    // EXECUTION CORE / D-BUS
    // --------------------------------------------------------
    cpu_core u_cpu_core (
        .clk            (clk),
        .rst            (rst),

        .core_enable    (core_enable),
        .instruction_word(instruction),
        .immediate_word (immediate_word),

        // ADC/SBC retain the existing fixed carry input behavior.
        .carry_in       (1'b0),

        .dbus_ready     (data_rsp.ready),
        .dbus_rdata     (data_rsp.rdata),

        .decode_valid   (decode_valid),
        .illegal_instr  (illegal_instr),
        .retire_valid   (retire_valid),

        .redirect       (redirect),
        .redirect_target(redirect_target),

        .dbus_valid     (dbus_valid),
        .dbus_write     (dbus_write),
        .dbus_addr      (dbus_addr),
        .dbus_wdata     (dbus_wdata),

        .operand_a      (operand_a),
        .operand_b      (operand_b),
        .alu_result     (alu_result),

        .flags          (flags),
        .status         (status)
    );

endmodule
