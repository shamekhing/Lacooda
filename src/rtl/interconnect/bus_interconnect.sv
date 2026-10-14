`timescale 1ns/1ps

// ============================================================
// LACOODA DATA BUS INTERCONNECT
// ============================================================
//
// Routes the CPU data bus to:
//
//   - Internal data RAM
//   - GPU MMIO
//
// Stage 1 remains single-master.
//
// A multi-master arbiter will be introduced before GPU DMA.
//
// Responsibilities:
//
//   1. Decode global addresses.
//   2. Reject misaligned requests.
//   3. Forward the complete request, including wstrb.
//   4. Translate global addresses into local addresses.
//   5. Return the selected slave response.
//   6. Report unmapped addresses as bus errors.
//
// The interconnect does not register requests or responses.
// It preserves the latency of the selected slave.
// ============================================================

module bus_interconnect (

    // CPU data bus.
    input  bus_pkg::bus_req_s dbus_req,
    output bus_pkg::bus_rsp_s dbus_rsp,

    // Internal RAM.
    output bus_pkg::bus_req_s data_ram_req,
    input  bus_pkg::bus_rsp_s data_ram_rsp,

    // GPU MMIO.
    output bus_pkg::bus_req_s gpu_mmio_req,
    input  bus_pkg::bus_rsp_s gpu_mmio_rsp

);

    // ========================================================
    // ADDRESS DECODER OUTPUTS
    // ========================================================

    logic data_ram_sel;
    logic gpu_mmio_sel;
    logic addr_aligned;

    address_decoder u_address_decoder (
        .addr         (dbus_req.addr),
        .data_ram_sel (data_ram_sel),
        .gpu_mmio_sel (gpu_mmio_sel)
    );

    assign addr_aligned =
        bus_pkg::bus_is_aligned(dbus_req.addr);

    // ========================================================
    // DATA RAM REQUEST
    // ========================================================
    //
    // Forward every request field.
    //
    // Only modify:
    //   - valid: Assert only when selected and aligned.
    //   - addr : Convert global to local address.
    // ========================================================

    always_comb begin

        data_ram_req = '0;

        if (
            dbus_req.valid &&
            addr_aligned &&
            data_ram_sel
        ) begin

            data_ram_req = dbus_req;

            data_ram_req.addr =
                dbus_req.addr - bus_pkg::DATA_RAM_BASE;

        end

    end

    // ========================================================
    // GPU MMIO REQUEST
    // ========================================================

    always_comb begin

        gpu_mmio_req = '0;

        if (
            dbus_req.valid &&
            addr_aligned &&
            gpu_mmio_sel
        ) begin

            gpu_mmio_req = dbus_req;

            gpu_mmio_req.addr =
                dbus_req.addr - bus_pkg::GPU_BASE;

        end

    end

    // ========================================================
    // RESPONSE MULTIPLEXER
    // ========================================================
    //
    // No request:
    //   ready = 0
    //
    // Misaligned address:
    //   ready = 1
    //   error = 1
    //
    // Mapped address:
    //   Return the selected slave response.
    //
    // Unmapped address:
    //   ready = 1
    //   error = 1
    //
    // DDR3 is currently unmapped.
    // ========================================================

    always_comb begin

        dbus_rsp = '0;

        if (dbus_req.valid) begin

            if (!addr_aligned) begin

                dbus_rsp = bus_pkg::bus_failure();

            end else if (data_ram_sel) begin

                dbus_rsp = data_ram_rsp;

            end else if (gpu_mmio_sel) begin

                dbus_rsp = gpu_mmio_rsp;

            end else begin

                dbus_rsp = bus_pkg::bus_failure();

            end

        end

    end

endmodule