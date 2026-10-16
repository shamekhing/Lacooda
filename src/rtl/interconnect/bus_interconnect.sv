`timescale 1ns / 1ps

// ============================================================
// LACOODA BUS INTERCONNECT — STAGE 2
// ============================================================
//
// Single-master CPU data bus interconnect.
//
// Connected slaves:
//   - Internal data RAM
//   - GPU MMIO
//
// Reserved regions:
//   - TPU MMIO
//   - DMA MMIO
//   - microSD MMIO
//   - System MMIO
//   - External DDR3
//
// Responsibilities:
//
//   1. Decode the global CPU address.
//   2. Validate word alignment.
//   3. Forward requests to the selected slave.
//   4. Translate the global byte address to a local address.
//   5. Forward byte write strobes without modification.
//   6. Return the selected slave response.
//   7. Complete invalid and reserved accesses with errors.
//
// IMPORTANT:
//
//   This interconnect is combinational.
//
//   It does not register, arbitrate, buffer or reorder
//   transactions.
//
//   The CPU master must preserve its request until the
//   selected slave completes the transaction.
//
//   Bus-master arbitration is deferred to Stage 4.
// ============================================================

module bus_interconnect (

    // ========================================================
    // CPU DATA BUS
    // ========================================================

    input  bus_pkg::bus_req_s dbus_req,
    output bus_pkg::bus_rsp_s dbus_rsp,

    // ========================================================
    // INTERNAL DATA RAM
    // ========================================================

    output bus_pkg::bus_req_s data_ram_req,
    input  bus_pkg::bus_rsp_s data_ram_rsp,

    // ========================================================
    // GPU MMIO
    // ========================================================

    output bus_pkg::bus_req_s gpu_mmio_req,
    input  bus_pkg::bus_rsp_s gpu_mmio_rsp

);

  // ========================================================
  // ADDRESS DECODER SIGNALS
  // ========================================================

  logic data_ram_sel;
  logic gpu_mmio_sel;

  logic addr_aligned;

  bus_pkg::bus_decode_s decode;

  // ========================================================
  // ADDRESS DECODER
  // ========================================================

  address_decoder u_address_decoder (

      .addr(dbus_req.addr),

      .data_ram_sel(data_ram_sel),
      .gpu_mmio_sel(gpu_mmio_sel),

      .decode(decode)

  );

  // ========================================================
  // ADDRESS ALIGNMENT
  // ========================================================
  //
  // Stage 2 enforces word alignment at the interconnect.
  //
  // Peripheral requests are suppressed for misaligned
  // global addresses.
  //
  // A misaligned request completes with an error instead.
  // ========================================================

  assign addr_aligned = bus_pkg::bus_is_aligned(dbus_req.addr);

  // ========================================================
  // INTERNAL DATA RAM REQUEST
  // ========================================================
  //
  // Forward the complete request only when:
  //
  //   - CPU request is valid.
  //   - Address is aligned.
  //   - Decoder selects internal RAM.
  //
  // The RAM receives its local byte address.
  //
  // All other fields, including the write strobes,
  // are preserved.
  // ========================================================

  always_comb begin

    data_ram_req = '0;

    if (dbus_req.valid && addr_aligned && data_ram_sel) begin

      data_ram_req = dbus_req;

      data_ram_req.addr = decode.local_addr;

    end

  end

  // ========================================================
  // GPU MMIO REQUEST
  // ========================================================
  //
  // GPU registers receive addresses relative to GPU_BASE.
  //
  // Example:
  //
  //   CPU global address = 0x10000014
  //   GPU base           = 0x10000000
  //
  //   GPU local address  = 0x00000014
  // ========================================================

  always_comb begin

    gpu_mmio_req = '0;

    if (dbus_req.valid && addr_aligned && gpu_mmio_sel) begin

      gpu_mmio_req = dbus_req;

      gpu_mmio_req.addr = decode.local_addr;

    end

  end

  // ========================================================
  // RESPONSE ROUTING
  // ========================================================
  //
  // The response is selected using the same decode result
  // as the outgoing slave request.
  //
  // Idle request:
  //   No response.
  //
  // Misaligned request:
  //   Immediate bus error.
  //
  // Connected RAM:
  //   Return RAM response.
  //
  // Connected GPU:
  //   Return GPU response.
  //
  // Reserved address:
  //   Immediate bus error.
  //
  // Unmapped address:
  //   Immediate bus error.
  //
  // The request master must hold the address stable while
  // awaiting a delayed slave response.
  // ========================================================

  always_comb begin

    dbus_rsp = '0;

    if (dbus_req.valid) begin

      if (!addr_aligned) begin

        dbus_rsp = bus_pkg::bus_failure();

      end else if (decode.implemented && (decode.device == bus_pkg::DEVICE_DATA_RAM)) begin

        dbus_rsp = data_ram_rsp;

      end else if (decode.implemented && (decode.device == bus_pkg::DEVICE_GPU_MMIO)) begin

        dbus_rsp = gpu_mmio_rsp;

      end else begin

        // Until Stage 3, DDR3 and unimplemented TPU,
        // DMA, microSD, and system-control registers fail.

        dbus_rsp = bus_pkg::bus_failure();

      end

    end

  end

endmodule
