`timescale 1ns/1ps

// ============================================================
// LACOODA DATA BUS INTERCONNECT — STAGE 3
// ============================================================
//
// One upstream master:
//   CPU data bus
//
// Three connected downstream slaves:
//   Internal data RAM
//   GPU MMIO
//   DDR3 bridge
//
// Global addresses are converted to device-local
// byte addresses.
//
// Unmapped addresses and unimplemented devices return
// an immediate error response.
//
// The interconnect is combinational.
//
// The master must hold request fields stable until the
// selected slave returns ready.
//
// Arbitration is not implemented here.
// ============================================================

module bus_interconnect (

    // CPU data bus
    input  bus_pkg::bus_req_s shared_bus_req,
    output bus_pkg::bus_rsp_s shared_bus_rsp,

    // Internal data RAM
    output bus_pkg::bus_req_s ram_bus_req,
    input  bus_pkg::bus_rsp_s ram_bus_rsp,

    // GPU MMIO
    output bus_pkg::bus_req_s gpu_mmio_bus_req,
    input  bus_pkg::bus_rsp_s gpu_mmio_bus_rsp,

    // DDR3 bridge
    output bus_pkg::bus_req_s ddr3_bus_req,
    input  bus_pkg::bus_rsp_s ddr3_bus_rsp
);

    // ========================================================
    // ADDRESS DECODE
    // ========================================================
    //
    // Reuse the authoritative decoder function.
    //
    // This avoids depending on a particular version of
    // the separate address_decoder module's port list.
    //
    // The existing address_decoder.sv can remain unchanged.
    // ========================================================

    bus_pkg::bus_decode_s decode;

    logic address_aligned;

    always_comb begin
        decode = bus_pkg::bus_decode_address(shared_bus_req.addr);
    end

    assign address_aligned =
        bus_pkg::bus_is_aligned(shared_bus_req.addr);

    // ========================================================
    // RAM REQUEST
    // ========================================================

    always_comb begin

        ram_bus_req = '0;

        if (
            shared_bus_req.valid &&
            address_aligned &&
            decode.implemented &&
            (decode.device == bus_pkg::DEVICE_DATA_RAM)
        ) begin

            ram_bus_req = shared_bus_req;
            ram_bus_req.addr = decode.local_addr;

        end

    end

    // ========================================================
    // GPU REQUEST
    // ========================================================

    always_comb begin

        gpu_mmio_bus_req = '0;

        if (
            shared_bus_req.valid &&
            address_aligned &&
            decode.implemented &&
            (decode.device == bus_pkg::DEVICE_GPU_MMIO)
        ) begin

            gpu_mmio_bus_req = shared_bus_req;
            gpu_mmio_bus_req.addr = decode.local_addr;

        end

    end

    // ========================================================
    // DDR3 REQUEST
    // ========================================================
    //
    // Forward the native bus transaction unchanged,
    // except for translating its address to a DDR3-local
    // byte address.
    // ========================================================

    always_comb begin

        ddr3_bus_req = '0;

        if (
            shared_bus_req.valid &&
            address_aligned &&
            decode.implemented &&
            (decode.device == bus_pkg::DEVICE_DDR3)
        ) begin

            ddr3_bus_req = shared_bus_req;
            ddr3_bus_req.addr = decode.local_addr;

        end

    end

    // ========================================================
    // RESPONSE MULTIPLEXER
    // ========================================================
    //
    // Idle:
    //   No response.
    //
    // Invalid alignment:
    //   Immediate bus error.
    //
    // Connected device:
    //   Forward the device's actual response.
    //
    // Unmapped or reserved device:
    //   Immediate bus error.
    // ========================================================

    always_comb begin

        shared_bus_rsp = '0;

        if (shared_bus_req.valid) begin

            if (!address_aligned) begin

                shared_bus_rsp = bus_pkg::bus_failure();

            end else begin

                case (decode.device)

                    bus_pkg::DEVICE_DATA_RAM: begin

                        if (decode.implemented)
                            shared_bus_rsp = ram_bus_rsp;
                        else
                            shared_bus_rsp = bus_pkg::bus_failure();

                    end

                    bus_pkg::DEVICE_GPU_MMIO: begin

                        if (decode.implemented)
                            shared_bus_rsp = gpu_mmio_bus_rsp;
                        else
                            shared_bus_rsp = bus_pkg::bus_failure();

                    end

                    bus_pkg::DEVICE_DDR3: begin

                        if (decode.implemented)
                            shared_bus_rsp = ddr3_bus_rsp;
                        else
                            shared_bus_rsp = bus_pkg::bus_failure();

                    end

                    default: begin

                        shared_bus_rsp = bus_pkg::bus_failure();

                    end

                endcase

            end

        end

    end

endmodule