`timescale 1ns/1ps

// ============================================================
// Local data mem — bus slave
//
// This is the first slave attached to the LACOODA CPU data bus.
// It preserves the Stage-7 mem semantics while speaking the new
// valid/ready request protocol.
//
// Addressing:
//   - CPU addresses are byte addresses.
//   - Each entry stores one global word (cpu_pkg::WORD_WIDTH).
//   - Valid accesses must be word aligned and inside DATA_MEMORY_COUNT.
//
// Timing:
//   - This local mem is always able to complete a request immediately.
//   - Therefore slave_ready follows slave_valid combinationally.
//   - LOAD data is combinational.
//   - STORE commits on the rising edge of an accepted transaction.
//
// Invalid addresses still complete instead of deadlocking the CPU:
//   - invalid LOAD returns zero
//   - invalid STORE is ignored
// ============================================================

module data_memory (
    input  logic                   clk,

    input  bus_pkg::bus_req_s  ibus_req,
    output bus_pkg::bus_rsp_s  ibus_rsp
);

    cpu_pkg::word_t mem [0:cpu_pkg::DATA_MEMORY_COUNT-1];
    logic addr_valid;
    cpu_pkg::word_t rdata;

    // Deterministic simulation/FPGA initialization.
    initial begin
        for (int idx = 0; idx < cpu_pkg::DATA_MEMORY_COUNT; idx++)
            mem[idx] = '0;
    end

    // The local memory itself never inserts wait states. Keeping ready tied
    // to valid makes the completion condition explicit: valid && ready.
    assign ibus_rsp = {ibus_req.valid, rdata};

    // Alignment/range check used by both reads and writes.
    always_comb begin
        addr_valid =
            (ibus_req.addr % cpu_pkg::WORD_BYTES == 0) &&
            ((ibus_req.addr / cpu_pkg::WORD_BYTES) < cpu_pkg::DATA_MEMORY_COUNT);
    end

    // LOAD response. STORE and idle cycles return zero on slave_read_data.
    always_comb begin
        rdata = '0;

        if (ibus_req.valid && ibus_req.op == bus_pkg::BUS_READ && addr_valid)
            rdata = mem[ibus_req.addr / cpu_pkg::WORD_BYTES];
    end

    // STORE commits exactly once on an accepted write transaction.
    always_ff @(posedge clk) begin
        if (ibus_req.valid && ibus_rsp.ready &&
            ibus_req.op == bus_pkg::BUS_WRITE && addr_valid)
            mem[ibus_req.addr / cpu_pkg::WORD_BYTES] <= ibus_req.wdata;
    end

endmodule
