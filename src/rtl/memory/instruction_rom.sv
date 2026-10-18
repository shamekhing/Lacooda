`timescale 1ns/1ps

// ============================================================
// LACOODA INSTRUCTION ROM
// ============================================================
//
// Independent instruction-bus slave.
//
// The ROM stores architectural words containing either:
//
//   - An instruction
//   - An immediate word
//
// The instruction-fetch unit decides which word to request.
//
// ROM data and response are registered. A request is accepted on one
// rising edge and acknowledged during the following cycle.
//
// Invalid accesses complete with an error.
//
// Instruction writes are not permitted.
//
// IMPORTANT:
//   The old packed concatenation:
//
//       assign cpu_instr_bus_rsp = {cpu_instr_bus_req.valid, rdata};
//
//   is no longer valid after adding the response error bit.
//
//   Every response field is now assigned explicitly.
// ============================================================

module instruction_rom (

    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s cpu_instr_bus_req,
    output bus_pkg::bus_rsp_s cpu_instr_bus_rsp

);

    // ========================================================
    // ROM ARRAY
    // ========================================================

    cpu_pkg::instruction_t rom_words [
        0 : memory_pkg::INSTRUCTION_ROM_WORDS-1
    ];

    // ========================================================
    // INITIALIZATION
    // ========================================================

    initial begin

        $readmemh(
            memory_pkg::INSTRUCTION_ROM_INIT_FILE,
            rom_words
        );

    end

    // ========================================================
    // ADDRESS VALIDATION
    // ========================================================

    logic addr_aligned;
    logic addr_in_range;
    logic addr_valid;

    assign addr_aligned =
        bus_pkg::bus_is_aligned(cpu_instr_bus_req.addr);

    assign addr_in_range =
        (cpu_instr_bus_req.addr / cpu_pkg::WORD_BYTES)
        < memory_pkg::INSTRUCTION_ROM_WORDS;

    assign addr_valid =
        addr_aligned && addr_in_range;

    // ========================================================
    // REGISTERED RESPONSE
    // ========================================================
    //
    // A valid read completes after one rising edge.
    //
    // A misaligned or out-of-range request returns an error.
    //
    // A write request also returns an error.
    //
    // The ROM array is never modified.
    // ========================================================

    logic response_pending;
    bus_pkg::bus_rsp_s response_reg;

    assign cpu_instr_bus_rsp = response_pending ? response_reg : '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            response_pending <= 1'b0;
            response_reg <= '0;
        end else if (response_pending) begin
            response_pending <= 1'b0;
        end else if (cpu_instr_bus_req.valid) begin
            response_pending <= 1'b1;
            response_reg.ready <= 1'b1;
            response_reg.error <= (cpu_instr_bus_req.op != bus_pkg::BUS_READ) || !addr_valid;
            if ((cpu_instr_bus_req.op == bus_pkg::BUS_READ) && addr_valid)
                response_reg.rdata <= cpu_pkg::word_t'(
                    rom_words[cpu_instr_bus_req.addr / cpu_pkg::WORD_BYTES]);
            else
                response_reg.rdata <= '0;
        end
    end

endmodule
