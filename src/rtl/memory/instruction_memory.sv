`timescale 1ns/1ps

// ============================================================
// Local instruction memory — instruction-bus slave
//
// This ROM is outside the CPU boundary. It implements the same valid/ready
// protocol as other external CPU resources while retaining the original
// combinational ROM behavior.
//
// Addressing:
//   - addresses are byte addresses
//   - one entry stores one global word (cpu_pkg::WORD_WIDTH): either an
//     instruction or the immediate word that follows it
//   - misaligned/out-of-range reads complete and return zero
//
// Timing:
//   - this local ROM inserts no wait states
//   - slave_ready follows slave_valid
//   - slave_read_data is combinational
// ============================================================

module instruction_memory (
    input  bus_pkg::bus_req_s  ibus_req,
    output bus_pkg::bus_rsp_s  ibus_rsp
);

    cpu_pkg::instruction_t mem [0:memory_pkg::INSTRUCTION_MEMORY_COUNT-1];
    logic addr_valid;
    cpu_pkg::word_t rdata;

    initial begin
        $readmemh(memory_pkg::PROGRAM_FILE, mem);
    end

    assign ibus_rsp = {ibus_req.valid, rdata};

    always_comb begin // check for valid in range address
        addr_valid = (ibus_req.addr % cpu_pkg::WORD_BYTES == 0) &&
            ((ibus_req.addr / cpu_pkg::WORD_BYTES) < memory_pkg::INSTRUCTION_MEMORY_COUNT);
    end

    always_comb begin
        rdata = '0;
        if (ibus_req.valid && addr_valid)
            rdata = cpu_pkg::word_t'(mem[ibus_req.addr / cpu_pkg::WORD_BYTES]);
    end

endmodule
