`timescale 1ns/1ps
`ifndef RPU_PKG_SV
`define RPU_PKG_SV

// ============================================================
// LACOODA ROUTING PROCESSING UNIT PACKAGE — STAGE 5
// ============================================================
//
// Routing policy lives here. The bus protocol (bus_req_s /
// bus_rsp_s, valid/ready, strobes and error responses) remains
// in bus_pkg.sv.
//
// ROUTE TABLE
//
//  Region         Base          Limit         Slave       Access
//  ------------   -----------   -----------   ---------   -----------------
//  ROM            0x0000_0000   0x0000_8000   ROM         CPU_I only
//  DATA_RAM       0x0000_0000   0x0000_8000   DATA_RAM    CPU_D, GPU, TPU
//  GPU_MMIO       0x1000_0000   0x1000_1000   GPU_MMIO    CPU_D, GPU, TPU
//  TPU_MMIO       0x1000_1000   0x1000_2000   reserved    mapped, no slave
//  DMA_MMIO       0x1000_2000   0x1000_3000   reserved    mapped, no slave
//  SD_MMIO        0x1000_3000   0x1000_4000   reserved    mapped, no slave
//  SYSTEM_MMIO    0x1000_4000   0x1000_5000   reserved    mapped, no slave
//  DDR3           0x8000_0000   0x8800_0000   DDR3        CPU_D, GPU, TPU
//
// The ROM/RAM overlap at 0x0000_0000 is intentional. The CPU
// instruction master sees ROM; data masters see DATA_RAM.
// Overlap is therefore validated per master, not globally.
//
// The fabric is a fixed 4 x 4 because Icarus Verilog 12 cannot
// elaborate unpacked-array parameters, two-dimensional arrays,
// or array slices. Extending the fabric means extending the
// explicit ports in rpu_crossbar.sv / rpu_top.sv and the
// identifiers below.
// ============================================================

package rpu_pkg;

    import cpu_pkg::*;
    import memory_pkg::*;

    localparam int RPU_MASTERS = 4;
    localparam int RPU_SLAVES  = 4;

    localparam int RPU_MASTER_ID_W = 2;
    localparam int RPU_SLAVE_ID_W  = 4;   // includes RPU_S_NONE

    // ========================================================
    // MASTER IDENTIFIERS
    // ========================================================

    typedef enum logic [RPU_MASTER_ID_W-1:0] {
        RPU_M_CPU_I = 2'd0,
        RPU_M_CPU_D = 2'd1,
        RPU_M_GPU   = 2'd2,
        RPU_M_TPU   = 2'd3
    } rpu_master_e;

    // ========================================================
    // SLAVE / PORT IDENTIFIERS
    // ========================================================
    //
    // 0 : ROM
    // 1 : DATA_RAM
    // 2 : GPU_MMIO
    // 3 : DDR3
    //
    // RPU_S_NONE is deliberately outside 0..RPU_SLAVES-1.
    // ========================================================

    typedef enum logic [RPU_SLAVE_ID_W-1:0] {
        RPU_S_ROM      = 4'd0,
        RPU_S_DATA_RAM = 4'd1,
        RPU_S_GPU_MMIO = 4'd2,
        RPU_S_DDR3     = 4'd3,
        RPU_S_NONE     = 4'hF
    } rpu_slave_e;

    // ========================================================
    // MASTER PERMISSION MASKS
    // ========================================================
    //
    // Bit n corresponds to rpu_master_e value n.
    // ========================================================

    localparam logic [RPU_MASTERS-1:0] RPU_MASK_CPU_I = 4'b0001;
    localparam logic [RPU_MASTERS-1:0] RPU_MASK_DATA  = 4'b1110;

    // ========================================================
    // ROUTE RESULT
    // ========================================================
    //
    // mapped : address lies inside a declared region
    // valid  : region is implemented and permitted for the master
    // slave  : destination slave port, or RPU_S_NONE
    // local  : slave-local byte address (global address - base)
    // ========================================================

    typedef struct packed {
        logic           valid;
        logic           mapped;
        rpu_slave_e     slave;
        cpu_pkg::word_t local_addr;
    } rpu_route_s;

    // ========================================================
    // SLAVE CAPABILITY MODEL
    // ========================================================
    //
    // Architectural properties of the hardware that actually
    // exists. They are descriptive, not runtime-configurable.
    //
    // total_ports            independent operation slots
    // read_ports             independent read-capable slots
    // write_ports            independent write-capable slots
    // max_outstanding        accepted-but-not-completed transactions
    // concurrent_read_write  a read and a write may overlap
    // response_latency       0 = same cycle, 1 = next cycle,
    //                        255 = variable / multi-cycle
    //
    // A single-port data RAM has read_ports=1, write_ports=1,
    // total_ports=1 and concurrent_read_write=0: reads and
    // writes share the same operation slot.
    // ========================================================

    typedef struct packed {
        logic [1:0] read_ports;
        logic [1:0] write_ports;
        logic [1:0] total_ports;
        logic [1:0] max_outstanding;
        logic       concurrent_read_write;
        logic [7:0] response_latency;
    } rpu_slave_caps_s;

    function automatic rpu_slave_caps_s rpu_slave_caps(
        input rpu_slave_e slave
    );

        rpu_slave_caps_s caps;

        caps = '0;

        case (slave)

            RPU_S_ROM: begin
                caps.read_ports  = 2'd1;
                caps.write_ports = 2'd0;
                caps.total_ports = 2'd1;
                caps.max_outstanding = 2'd1;
                caps.concurrent_read_write = 1'b0;
                caps.response_latency = 8'd1;
            end

            RPU_S_DATA_RAM: begin
                caps.read_ports  = 2'd1;
                caps.write_ports = 2'd1;
                caps.total_ports = 2'd1;
                caps.max_outstanding = 2'd1;
                caps.concurrent_read_write = 1'b0;
                caps.response_latency = 8'd1;
            end

            RPU_S_GPU_MMIO: begin
                caps.read_ports  = 2'd1;
                caps.write_ports = 2'd1;
                caps.total_ports = 2'd1;
                caps.max_outstanding = 2'd1;
                caps.concurrent_read_write = 1'b0;
                caps.response_latency = 8'd0;
            end

            RPU_S_DDR3: begin
                caps.read_ports  = 2'd1;
                caps.write_ports = 2'd1;
                caps.total_ports = 2'd1;
                caps.max_outstanding = 2'd1;
                caps.concurrent_read_write = 1'b0;
                caps.response_latency = 8'd255;
            end

            default: caps = '0;

        endcase

        return caps;

    endfunction

    // ========================================================
    // REGION CONSTANTS
    // ========================================================

    localparam cpu_pkg::word_t RPU_ROM_BASE  = cpu_pkg::word_t'(32'h0000_0000);
    localparam cpu_pkg::word_t RPU_ROM_SIZE  = cpu_pkg::word_t'(memory_pkg::INSTRUCTION_ROM_BYTES);
    localparam cpu_pkg::word_t RPU_ROM_LIMIT = RPU_ROM_BASE + RPU_ROM_SIZE;

    localparam cpu_pkg::word_t RPU_RAM_BASE  = cpu_pkg::word_t'(32'h0000_0000);
    localparam cpu_pkg::word_t RPU_RAM_SIZE  = cpu_pkg::word_t'(memory_pkg::DATA_RAM_BYTES);
    localparam cpu_pkg::word_t RPU_RAM_LIMIT = RPU_RAM_BASE + RPU_RAM_SIZE;

    localparam cpu_pkg::word_t RPU_GPU_BASE  = cpu_pkg::word_t'(32'h1000_0000);
    localparam cpu_pkg::word_t RPU_GPU_SIZE  = cpu_pkg::word_t'(memory_pkg::GPU_MMIO_BYTES);
    localparam cpu_pkg::word_t RPU_GPU_LIMIT = RPU_GPU_BASE + RPU_GPU_SIZE;

    localparam cpu_pkg::word_t RPU_TPU_BASE  = cpu_pkg::word_t'(32'h1000_1000);
    localparam cpu_pkg::word_t RPU_TPU_LIMIT = cpu_pkg::word_t'(32'h1000_2000);

    localparam cpu_pkg::word_t RPU_DMA_BASE  = cpu_pkg::word_t'(32'h1000_2000);
    localparam cpu_pkg::word_t RPU_DMA_LIMIT = cpu_pkg::word_t'(32'h1000_3000);

    localparam cpu_pkg::word_t RPU_SD_BASE  = cpu_pkg::word_t'(32'h1000_3000);
    localparam cpu_pkg::word_t RPU_SD_LIMIT = cpu_pkg::word_t'(32'h1000_4000);

    localparam cpu_pkg::word_t RPU_SYSTEM_BASE  = cpu_pkg::word_t'(32'h1000_4000);
    localparam cpu_pkg::word_t RPU_SYSTEM_LIMIT = cpu_pkg::word_t'(32'h1000_5000);

    localparam cpu_pkg::word_t RPU_DDR3_BASE  = cpu_pkg::word_t'(32'h8000_0000);
    localparam cpu_pkg::word_t RPU_DDR3_SIZE  = cpu_pkg::word_t'(memory_pkg::DDR3_BYTES);
    localparam cpu_pkg::word_t RPU_DDR3_LIMIT = RPU_DDR3_BASE + RPU_DDR3_SIZE;

    // ========================================================
    // ADDRESS DECODER
    // ========================================================
    //
    // Pure combinational policy. An address outside every
    // declared region returns mapped = 0, valid = 0.
    //
    // A mapped region with no connected slave returns
    // mapped = 1, valid = 0 so the fabric returns a bus
    // error instead of silently accepting the access.
    // ========================================================

    function automatic rpu_route_s rpu_decode(
        input rpu_master_e master,
        input cpu_pkg::word_t addr
    );

        rpu_route_s result;

        result = '0;
        result.slave = RPU_S_NONE;
        result.local_addr = addr;

        case (master)

            // -------------------------------------------------
            // INSTRUCTION MASTER
            // -------------------------------------------------

            RPU_M_CPU_I: begin

                if (addr < RPU_ROM_LIMIT) begin

                    result.mapped     = 1'b1;
                    result.valid      = 1'b1;
                    result.slave      = RPU_S_ROM;
                    result.local_addr = addr - RPU_ROM_BASE;

                end

            end

            // -------------------------------------------------
            // DATA MASTERS
            // -------------------------------------------------

            RPU_M_CPU_D,
            RPU_M_GPU,
            RPU_M_TPU: begin

                if (addr < RPU_RAM_LIMIT) begin

                    result.mapped     = 1'b1;
                    result.valid      = 1'b1;
                    result.slave      = RPU_S_DATA_RAM;
                    result.local_addr = addr - RPU_RAM_BASE;

                end else if (
                    (addr >= RPU_GPU_BASE) &&
                    (addr < RPU_GPU_LIMIT)
                ) begin

                    result.mapped     = 1'b1;
                    result.valid      = 1'b1;
                    result.slave      = RPU_S_GPU_MMIO;
                    result.local_addr = addr - RPU_GPU_BASE;

                end else if (
                    (addr >= RPU_TPU_BASE) &&
                    (addr < RPU_TPU_LIMIT)
                ) begin

                    // Reserved: mapped but not implemented.

                    result.mapped = 1'b1;
                    result.valid  = 1'b0;
                    result.slave  = RPU_S_NONE;

                end else if (
                    (addr >= RPU_DMA_BASE) &&
                    (addr < RPU_DMA_LIMIT)
                ) begin

                    result.mapped = 1'b1;
                    result.valid  = 1'b0;
                    result.slave  = RPU_S_NONE;

                end else if (
                    (addr >= RPU_SD_BASE) &&
                    (addr < RPU_SD_LIMIT)
                ) begin

                    result.mapped = 1'b1;
                    result.valid  = 1'b0;
                    result.slave  = RPU_S_NONE;

                end else if (
                    (addr >= RPU_SYSTEM_BASE) &&
                    (addr < RPU_SYSTEM_LIMIT)
                ) begin

                    result.mapped = 1'b1;
                    result.valid  = 1'b0;
                    result.slave  = RPU_S_NONE;

                end else if (
                    (addr >= RPU_DDR3_BASE) &&
                    (addr < RPU_DDR3_LIMIT)
                ) begin

                    result.mapped     = 1'b1;
                    result.valid      = 1'b1;
                    result.slave      = RPU_S_DDR3;
                    result.local_addr = addr - RPU_DDR3_BASE;

                end

            end

            default: begin

                result.mapped = 1'b0;
                result.valid  = 1'b0;
                result.slave  = RPU_S_NONE;

            end

        endcase

        return result;

    endfunction


    // ========================================================
    // STATIC MAP VALIDATION
    // ========================================================
    //
    // Pure function, no side effects. Testbenches call it and
    // report failures with simulation-only system tasks.
    //
    // The data-master regions are listed in ascending order, so
    // checking adjacent pairs is sufficient for overlap.
    // ========================================================

    function automatic bit rpu_region_valid(
        input cpu_pkg::word_t base,
        input cpu_pkg::word_t limit
    );

        cpu_pkg::word_t size;

        size = limit - base;

        if (size == 0)
            return 1'b0;

        if (base >= limit)
            return 1'b0;

        // Power-of-two size.

        if ((size & (size - cpu_pkg::word_t'(1))) != 0)
            return 1'b0;

        // Base aligned to the region size.

        if ((base % size) != 0)
            return 1'b0;

        return 1'b1;

    endfunction

    function automatic bit rpu_regions_overlap(
        input cpu_pkg::word_t base_a,
        input cpu_pkg::word_t limit_a,
        input cpu_pkg::word_t base_b,
        input cpu_pkg::word_t limit_b
    );

        return
            (base_a < limit_b) &&
            (base_b < limit_a);

    endfunction

    function automatic bit rpu_validate_map();

        bit ok;

        ok = 1'b1;

        if (!rpu_region_valid(RPU_ROM_BASE, RPU_ROM_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_RAM_BASE, RPU_RAM_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_GPU_BASE, RPU_GPU_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_TPU_BASE, RPU_TPU_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_DMA_BASE, RPU_DMA_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_SD_BASE, RPU_SD_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_SYSTEM_BASE, RPU_SYSTEM_LIMIT))
            ok = 1'b0;

        if (!rpu_region_valid(RPU_DDR3_BASE, RPU_DDR3_LIMIT))
            ok = 1'b0;

        // Data-master view: adjacent regions must not overlap.
        // The regions are ordered, so adjacency is sufficient.

        if (rpu_regions_overlap(RPU_RAM_BASE, RPU_RAM_LIMIT,
                                RPU_GPU_BASE, RPU_GPU_LIMIT))
            ok = 1'b0;

        if (rpu_regions_overlap(RPU_GPU_BASE, RPU_GPU_LIMIT,
                                RPU_TPU_BASE, RPU_TPU_LIMIT))
            ok = 1'b0;

        if (rpu_regions_overlap(RPU_TPU_BASE, RPU_TPU_LIMIT,
                                RPU_DMA_BASE, RPU_DMA_LIMIT))
            ok = 1'b0;

        if (rpu_regions_overlap(RPU_DMA_BASE, RPU_DMA_LIMIT,
                                RPU_SD_BASE, RPU_SD_LIMIT))
            ok = 1'b0;

        if (rpu_regions_overlap(RPU_SD_BASE, RPU_SD_LIMIT,
                                RPU_SYSTEM_BASE, RPU_SYSTEM_LIMIT))
            ok = 1'b0;

        if (rpu_regions_overlap(RPU_SYSTEM_BASE, RPU_SYSTEM_LIMIT,
                                RPU_DDR3_BASE, RPU_DDR3_LIMIT))
            ok = 1'b0;

        // Implemented slave identifiers must exist in the fabric.

        if (int'(RPU_S_ROM) >= RPU_SLAVES)
            ok = 1'b0;

        if (int'(RPU_S_DATA_RAM) >= RPU_SLAVES)
            ok = 1'b0;

        if (int'(RPU_S_GPU_MMIO) >= RPU_SLAVES)
            ok = 1'b0;

        if (int'(RPU_S_DDR3) >= RPU_SLAVES)
            ok = 1'b0;

        return ok;

    endfunction

endpackage

`endif
