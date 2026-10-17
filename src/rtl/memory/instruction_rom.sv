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
// This implementation preserves the original combinational
// ROM behavior.
//
// There are no wait states.
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
    // COMBINATIONAL RESPONSE
    // ========================================================
    //
    // A valid read completes immediately.
    //
    // A misaligned or out-of-range request returns an error.
    //
    // A write request also returns an error.
    //
    // The ROM array is never modified.
    // ========================================================

    always_comb begin

        cpu_instr_bus_rsp = '0;

        if (cpu_instr_bus_req.valid) begin

            cpu_instr_bus_rsp.ready = 1'b1;

            if (
                (cpu_instr_bus_req.op == bus_pkg::BUS_READ) &&
                addr_valid
            ) begin

                cpu_instr_bus_rsp.rdata =
                    cpu_pkg::word_t'(
                        rom_words[
                            cpu_instr_bus_req.addr / cpu_pkg::WORD_BYTES
                        ]
                    );

                cpu_instr_bus_rsp.error = 1'b0;

            end else begin

                cpu_instr_bus_rsp.rdata = '0;
                cpu_instr_bus_rsp.error = 1'b1;

            end

        end

    end

endmodule