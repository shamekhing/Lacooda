`timescale 1ns / 1ps

// ============================================================
// LACOODA ADDRESS DECODER — STAGE 2
// ============================================================
//
// Purely combinational global address decoder.
//
// Input:
//   addr — CPU-visible global byte address.
//
// Outputs:
//
//   decode:
//       Complete device classification.
//       Contains device ID, local byte address,
//       mapped status and implementation status.
//
//   data_ram_sel:
//       Selects the connected internal data RAM.
//
//   gpu_mmio_sel:
//       Selects the connected GPU register block.
//
// The existing selection ports are preserved so Stage 1
// integration remains compatible.
//
// All global memory regions are defined exclusively in
// bus_pkg.sv.
//
// The decoder does not:
//   - Execute memory accesses.
//   - Modify data.
//   - Generate bus handshakes.
//   - Perform arbitration.
//   - Handle clock domains.
//
// Reserved regions are classified but never selected as
// connected slaves.
// ============================================================

module address_decoder (

    input cpu_pkg::word_t addr,

    output logic data_ram_sel,
    output logic gpu_mmio_sel,

    output bus_pkg::bus_decode_s decode

);

  // ========================================================
  // CENTRAL ADDRESS CLASSIFICATION
  // ========================================================
  //
  // Use the authoritative function from bus_pkg.
  //
  // Avoid duplicating address comparisons in this module.
  // ========================================================

  always_comb begin

    decode = bus_pkg::bus_decode_address(addr);

  end

  // ========================================================
  // CONNECTED SLAVE SELECTION
  // ========================================================
  //
  // DEVICE_DATA_RAM and DEVICE_GPU_MMIO are the only
  // implemented data-bus slaves in Stage 2.
  //
  // No reserved device is selected.
  // ========================================================

  always_comb begin

    data_ram_sel = 1'b0;
    gpu_mmio_sel = 1'b0;

    if (decode.implemented) begin

      case (decode.device)

        bus_pkg::DEVICE_DATA_RAM: begin

          data_ram_sel = 1'b1;

        end

        bus_pkg::DEVICE_GPU_MMIO: begin

          gpu_mmio_sel = 1'b1;

        end

        default: begin

          // No other peripheral is currently
          // connected to the data bus.

        end

      endcase

    end

  end

endmodule
