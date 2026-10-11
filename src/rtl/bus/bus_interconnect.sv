`timescale 1ns/1ps

module bus_interconnect (
    // CPU D-BUS
    input  bus_pkg::bus_req_s dbus_req,
    output bus_pkg::bus_rsp_s dbus_rsp,

    // Internal data BRAM
    output bus_pkg::bus_req_s data_mem_req,
    input  bus_pkg::bus_rsp_s data_mem_rsp,

    // GPU MMIO
    output bus_pkg::bus_req_s gpu_mmio_req,
    input  bus_pkg::bus_rsp_s gpu_mmio_rsp
);

    logic data_mem_sel;
    logic gpu_mmio_sel;

    // ========================================================
    // Address decoder
    // ========================================================

    address_decoder u_address_decoder (
        .addr            (dbus_req.addr),
        .data_mem_sel (data_mem_sel),
        .gpu_mmio_sel         (gpu_mmio_sel)
    );

    // ========================================================
    // Data-memory request
    // Global D-BUS address -> memory-local byte address.
    // ========================================================

    always_comb begin
        data_mem_req = '0;
        data_mem_req.valid = dbus_req.valid && data_mem_sel;
        data_mem_req.op = dbus_req.op;
        data_mem_req.addr = dbus_req.addr - bus_pkg::DATA_MEMORY_BASE;
        data_mem_req.wdata = dbus_req.wdata;
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
        gpu_mmio_req = '0;
        gpu_mmio_req.valid = dbus_req.valid && gpu_mmio_sel;
        gpu_mmio_req.op = dbus_req.op;
        gpu_mmio_req.addr = dbus_req.addr - bus_pkg::GPU_BASE;
        gpu_mmio_req.wdata = dbus_req.wdata;
    end

    // ========================================================
    // Response multiplexer
    // ========================================================

    always_comb begin
        dbus_rsp = '0;
        if (dbus_req.valid) begin
            if (data_mem_sel) begin
                dbus_rsp = data_mem_rsp;
            end else if (gpu_mmio_sel) begin
                dbus_rsp = gpu_mmio_rsp;
            end else begin
                // unmapped access completes immediately and
                // returns zero rather than raising a bus fault.
                dbus_rsp.ready = 1'b1;
                dbus_rsp.rdata = '0;
            end
        end
    end
endmodule