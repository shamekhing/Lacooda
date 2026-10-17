`timescale 1ns/1ps

// ============================================================
// LACOODA CPU WRAPPER
// ============================================================
//
// Preserves the original CPU hierarchy:
//
//   - instruction_fetch
//   - cpu_core
//
// External buses:
//
//   I-BUS : Instruction memory
//   D-BUS : Data memory and MMIO
//
// Stage 1 changes:
//
//   - Supply write strobes on D-BUS.
//   - Preserve existing instruction-fetch behavior.
//   - Preserve existing CPU core scalar interfaces.
//
// Current CPU stores are full-word stores.
//
// Bus and decode errors latch fault and halt execution until reset.
// This is a stop indication, not a vectored exception handler.
// ============================================================

module cpu (

    input logic clk,
    input logic rst,
    input logic run,

    output bus_pkg::bus_req_s cpu_instr_bus_req,
    input  bus_pkg::bus_rsp_s cpu_instr_bus_rsp,

    output bus_pkg::bus_req_s cpu_bus_req,
    input  bus_pkg::bus_rsp_s cpu_bus_rsp,

    output logic retire_valid,
    output logic illegal_instr,
    output logic fault

);

    // ========================================================
    // EXECUTION CONTROL
    // ========================================================

    logic core_enable;
    logic carry_flag;
    logic fetch_fault;
    logic fault_latched;
    assign fault = fault_latched;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) fault_latched <= 1'b0;
        else if (fetch_fault || (dbus_valid && cpu_bus_rsp.ready && cpu_bus_rsp.error) ||
                 (instruction_available && illegal_instr)) fault_latched <= 1'b1;
    end

    logic redirect;
    cpu_pkg::word_t redirect_target;

    // ========================================================
    // CPU CORE DATA BUS SIGNALS
    // ========================================================

    logic dbus_valid;
    logic dbus_write;

    cpu_pkg::word_t dbus_addr;
    cpu_pkg::word_t dbus_wdata;

    // ========================================================
    // DATA BUS REQUEST
    // ========================================================
    //
    // The CPU core exposes scalar memory signals.
    //
    // The wrapper converts them to the native bus structure.
    //
    // Full-word stores enable every byte lane.
    //
    // The interconnect and RAM perform address validation.
    // ========================================================

    assign cpu_bus_req.valid = dbus_valid;

    assign cpu_bus_req.op =
        dbus_write
            ? bus_pkg::BUS_WRITE
            : bus_pkg::BUS_READ;

    assign cpu_bus_req.addr  = dbus_addr;
    assign cpu_bus_req.wdata = dbus_wdata;
    assign cpu_bus_req.wstrb = bus_pkg::BUS_STRB_ALL;

    // ========================================================
    // INSTRUCTION EXECUTION ENABLE
    // ========================================================
    //
    // A buffered instruction may finish even if run falls.
    //
    // This prevents an active D-BUS request from being
    // abandoned before its response arrives.
    // ========================================================

    assign core_enable =
        instruction_available && !rst && !fault_latched;

    // ========================================================
    // FETCHED INSTRUCTION
    // ========================================================

    cpu_pkg::instruction_t instruction;
    cpu_pkg::word_t immediate_word;

    logic instruction_available;
    logic retire;

    // ========================================================
    // INSTRUCTION RETIREMENT
    // ========================================================

    assign retire =
        instruction_available &&
        !rst &&
        retire_valid && !fault_latched;

    // ========================================================
    // INSTRUCTION FETCH
    // ========================================================

    instruction_fetch u_instruction_fetch (

        .clk                   (clk),
        .rst                   (rst),
        .run                   (run && !fault_latched),

        .retire                (retire),

        .redirect              (redirect),
        .redirect_target       (redirect_target),

        .cpu_instr_bus_req              (cpu_instr_bus_req),
        .cpu_instr_bus_rsp              (cpu_instr_bus_rsp),

        .instruction           (instruction),
        .immediate_word        (immediate_word),

        .instruction_available (instruction_available),
        .fault                 (fetch_fault)

    );

    // ========================================================
    // EXECUTION CORE
    // ========================================================
    //
    // Failed data transactions complete the bus handshake but cannot
    // retire or write back. The wrapper latches the error as a fault.
    // ========================================================

    cpu_core u_cpu_core (

        .clk             (clk),
        .rst             (rst),

        .core_enable     (core_enable),

        .instruction_word(instruction),
        .immediate_word  (immediate_word),

        .carry_in        (carry_flag),
        .carry_flag      (carry_flag),

        .dbus_ready      (cpu_bus_rsp.ready),
        .dbus_rdata      (cpu_bus_rsp.rdata),

        .illegal_instr   (illegal_instr),
        .retire_valid    (retire_valid),

        .redirect        (redirect),
        .redirect_target (redirect_target),

        .dbus_valid      (dbus_valid),
        .dbus_write      (dbus_write),
        .dbus_addr       (dbus_addr),
        .dbus_wdata      (dbus_wdata)

    );

endmodule
