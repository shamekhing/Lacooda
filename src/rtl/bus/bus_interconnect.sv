`timescale 1ns/1ps

module bus_interconnect (
    // CPU D-BUS
    input  bus_pkg::bus_req_s d_req,
    output bus_pkg::bus_rsp_s d_rsp,

    // Internal data BRAM
    output bus_pkg::bus_req_s data_memory_req,
    input  bus_pkg::bus_rsp_s data_memory_rsp,

    // GPU MMIO
    output bus_pkg::bus_req_s gpu_req,
    input  bus_pkg::bus_rsp_s gpu_rsp
);

    logic data_memory_sel;
    logic gpu_sel;

    // ========================================================
    // Address decoder
    // ========================================================

    address_cpu_decoder u_address_cpu_decoder (
        .addr            (d_req.addr),
        .data_memory_sel (data_memory_sel),
        .gpu_sel         (gpu_sel)
    );

    // ========================================================
    // Data-memory request
    // ========================================================

    always_comb begin

        data_memory_req = '0;

        data_memory_req.valid =
            d_req.valid && data_memory_sel;

        data_memory_req.op =
            d_req.op;

        // Global D-BUS address -> memory-local byte address.
        data_memory_req.addr =
            d_req.addr - bus_pkg::DATA_MEMORY_BASE;

        data_memory_req.wdata =
            d_req.wdata;

    end

    // ========================================================
    // GPU request
    // ========================================================

    always_comb begin

        gpu_req = '0;

        gpu_req.valid =
            d_req.valid && gpu_sel;

        gpu_req.op =
            d_req.op;

        // Global address -> GPU-local address.
        //
        // Example:
        //
        // 0x10000020 - 0x10000000 = 0x20
        //
        // Decimal:
        //
        // 268435488 - 268435456 = 32
        gpu_req.addr =
            d_req.addr - bus_pkg::GPU_BASE;

        gpu_req.wdata =
            d_req.wdata;

    end

    // ========================================================
    // Response multiplexer
    // ========================================================

    always_comb begin

        d_rsp = '0;

        if (d_req.valid) begin

            if (data_memory_sel) begin

                d_rsp = data_memory_rsp;

            end else if (gpu_sel) begin

                d_rsp = gpu_rsp;

            end else begin

                // Existing LACOODA behavior:
                //
                // unmapped access completes immediately and
                // returns zero rather than raising a bus fault.

                d_rsp.ready = 1'b1;
                d_rsp.rdata = '0;

            end

        end

    end

endmodule