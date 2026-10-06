`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus interconnect
//
// Routes the CPU data-bus master to one of the implemented
// data-bus slaves.
//
// Stage 1 slaves:
//   - local data memory
//   - GPU MMIO
//
// The CPU continues to see one generic D-BUS. It does not need
// to know which physical slave owns an address.
//
// Protocol:
//   - Master holds request fields while waiting for ready.
//   - Only the selected slave receives valid=1.
//   - Selected slave response is returned to the master.
//   - Unmapped accesses complete immediately with rdata=0,
//     preserving the existing architectural behavior.
//
// Address translation:
//   CPU-visible addresses are translated into slave-local
//   offsets before being forwarded.
//
// Example:
//
//   CPU address:
//       0x1000_000C
//
//   GPU_BASE:
//       0x1000_0000
//
//   GPU receives:
//       0x0000_000C
// ============================================================

module bus_interconnect (
    // --------------------------------------------------------
    // CPU D-BUS master side
    // --------------------------------------------------------

    input  bus_pkg::bus_req_s d_req,
    output bus_pkg::bus_rsp_s d_rsp,

    // --------------------------------------------------------
    // Local data-memory slave side
    // --------------------------------------------------------

    output bus_pkg::bus_req_s data_memory_req,
    input  bus_pkg::bus_rsp_s data_memory_rsp,

    // --------------------------------------------------------
    // GPU slave side
    // --------------------------------------------------------

    output bus_pkg::bus_req_s gpu_req,
    input  bus_pkg::bus_rsp_s gpu_rsp
);

    // --------------------------------------------------------
    // Address decode results
    // --------------------------------------------------------

    logic data_memory_sel;
    logic gpu_sel;

    address_cpu_decoder u_address_cpu_decoder (
        .addr            (d_req.addr),
        .data_memory_sel (data_memory_sel),
        .gpu_sel         (gpu_sel)
    );

    // ========================================================
    // DATA MEMORY REQUEST
    // ========================================================
    //
    // The memory sees valid only when:
    //
    //   1. the CPU has an active transaction
    //   2. the address belongs to local data memory
    //
    // Convert the CPU-visible address into an address relative
    // to DATA_MEMORY_BASE.
    // ========================================================

    always_comb begin
        data_memory_req         = '0;
        data_memory_req.valid   = d_req.valid && data_memory_sel;
        data_memory_req.op      = d_req.op;
        data_memory_req.addr    = d_req.addr - bus_pkg::DATA_MEMORY_BASE;
        data_memory_req.wdata   = d_req.wdata;
    end

    // ========================================================
    // GPU REQUEST
    // ========================================================
    //
    // The GPU sees exactly the same bus protocol as memory.
    //
    // However, its address is translated into a GPU-local
    // offset.
    //
    // Example:
    //
    //   CPU: 0x1000_0020
    //         -
    //        0x1000_0000
    //         -----------
    //   GPU: 0x0000_0020
    // ========================================================

    always_comb begin
        gpu_req         = '0;
        gpu_req.valid   = d_req.valid && gpu_sel;
        gpu_req.op      = d_req.op;
        gpu_req.addr    = d_req.addr - bus_pkg::GPU_BASE;
        gpu_req.wdata   = d_req.wdata;
    end

    // ========================================================
    // RESPONSE ROUTING
    // ========================================================
    //
    // Exactly one selected slave should supply the CPU response.
    //
    // No request:
    //      ready = 0
    //
    // RAM:
    //      return data_memory_rsp
    //
    // GPU:
    //      return gpu_rsp
    //
    // Unmapped:
    //      ready = 1
    //      rdata = 0
    //
    // Immediate completion for unmapped accesses preserves the
    // behavior of the pre-GPU interconnect.
    // ========================================================

    always_comb begin
        d_rsp = '0;
        if (d_req.valid) begin
            if (data_memory_sel)  begin
                d_rsp = data_memory_rsp;
            end else if (gpu_sel) begin
                d_rsp = gpu_rsp;
            end else begin // Unmapped accesses do not stall the CPU.
                d_rsp.ready = 1'b1;
                d_rsp.rdata = '0;
            end
        end
    end

endmodule