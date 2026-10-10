`timescale 1ns/1ps

module bus_interconnect (
    // CPU D-BUS
    input  bus_pkg::bus_req_s cpu_req,
    output bus_pkg::bus_rsp_s cpu_rsp,

    // Internal data BRAM
    output bus_pkg::bus_req_s cpu_memory_req,
    input  bus_pkg::bus_rsp_s cpu_memory_rsp,

    // GPU MMIO
    output bus_pkg::bus_req_s gpu_req,
    input  bus_pkg::bus_rsp_s gpu_rsp
);

    logic cpu_memory_sel;
    logic gpu_sel;

    // ========================================================
    // Address decoder
    // ========================================================

    address_decoder u_address_decoder (
        .addr            (cpu_req.addr),
        .cpu_memory_sel (cpu_memory_sel),
        .gpu_sel         (gpu_sel)
    );

    // ========================================================
    // Data-memory request
    // Global D-BUS address -> memory-local byte address.
    // ========================================================

    always_comb begin
        cpu_memory_req = '0;
        cpu_memory_req.valid = cpu_req.valid && cpu_memory_sel;
        cpu_memory_req.op = cpu_req.op;
        cpu_memory_req.addr = cpu_req.addr - bus_pkg::CPU_MEMORY_BASE;
        cpu_memory_req.wdata = cpu_req.wdata;
    end

    // ========================================================
    // GPU request
    // Global address -> GPU-local address.
    //
    // Example:
    //
    // 0x10000020 - 0x10000000 = 0x20
    //
    // Decimal:
    //
    // 268435488 - 268435456 = 32
    // ========================================================

    always_comb begin
        gpu_req = '0;
        gpu_req.valid = cpu_req.valid && gpu_sel;
        gpu_req.op = cpu_req.op;
        gpu_req.addr = cpu_req.addr - bus_pkg::GPU_BASE;
        gpu_req.wdata = cpu_req.wdata;
    end

    // ========================================================
    // Response multiplexer
    // ========================================================

    always_comb begin
        cpu_rsp = '0;
        if (cpu_req.valid) begin
            if (cpu_memory_sel) begin
                cpu_rsp = cpu_memory_rsp;
            end else if (gpu_sel) begin
                cpu_rsp = gpu_rsp;
            end else begin
                // unmapped access completes immediately and
                // returns zero rather than raising a bus fault.
                cpu_rsp.ready = 1'b1;
                cpu_rsp.rdata = '0;
            end
        end
    end
endmodule