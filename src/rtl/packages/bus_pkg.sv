`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

package bus_pkg;

    // ========================================================
    // LACOODA NATIVE MEMORY BUS
    // ========================================================
    //
    // 32-bit address and data bus.
    // Byte-addressed, little-endian.
    //
    // A transaction completes at the rising clock edge when:
    //
    //     request.valid && response.ready
    //
    // Until completion, the master holds the request stable.
    //
    // One transaction per master may be outstanding.
    //
    // There are no bursts or transaction IDs in Stage 1.
    // ========================================================

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_e;

    // ========================================================
    // BYTE WRITE STROBES
    // ========================================================
    //
    // One strobe per byte.
    //
    // For a 32-bit data word:
    //
    //   bit 0 -> data[ 7: 0]
    //   bit 1 -> data[15: 8]
    //   bit 2 -> data[23:16]
    //   bit 3 -> data[31:24]
    //
    // '0 fills every bit with zero.
    // '1 fills every bit with one.
    // ========================================================

    localparam int BUS_STRB_WIDTH = cpu_pkg::WORD_BYTES;

    typedef logic [BUS_STRB_WIDTH-1:0] bus_strb_t;

    localparam bus_strb_t BUS_STRB_NONE = '0;
    localparam bus_strb_t BUS_STRB_ALL  = '1;

    // ========================================================
    // REQUEST
    // ========================================================
    //
    // valid : Request is active.
    // op    : Read or write.
    // addr  : Byte address.
    // wdata : Data supplied by a write.
    // wstrb : Enabled write bytes.
    //
    // Read operations ignore wstrb.
    // ========================================================

    typedef struct packed {
        logic           valid;
        bus_op_e        op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;
        bus_strb_t      wstrb;
    } bus_req_s;

    // ========================================================
    // RESPONSE
    // ========================================================
    //
    // ready : Transaction has completed.
    // rdata : Data returned by a successful read.
    // error : Transaction failed.
    //
    // rdata and error are meaningful only when ready = 1.
    // ========================================================

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
        logic           error;
    } bus_rsp_s;

    // ========================================================
    // DATA RAM
    // ========================================================
    //
    // 32 KiB internal RAM.
    //
    // Address range:
    //     0x00000000 through 0x00007FFF
    //
    // LIMIT is exclusive.
    // ========================================================

    localparam cpu_pkg::word_t DATA_RAM_BASE =
        cpu_pkg::word_t'(32'h0000_0000);

    localparam cpu_pkg::word_t DATA_RAM_SIZE =
        cpu_pkg::word_t'(memory_pkg::DATA_RAM_WORDS)
        * cpu_pkg::word_t'(cpu_pkg::WORD_BYTES);

    localparam cpu_pkg::word_t DATA_RAM_LIMIT =
        DATA_RAM_BASE + DATA_RAM_SIZE;

    // ========================================================
    // GPU MMIO
    // ========================================================
    //
    // 4 KiB reserved address space.
    //
    // This is register address space, not allocated RAM.
    // ========================================================

    localparam cpu_pkg::word_t GPU_BASE =
        cpu_pkg::word_t'(32'h1000_0000);

    localparam cpu_pkg::word_t GPU_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t GPU_LIMIT =
        GPU_BASE + GPU_SIZE;

    // ========================================================
    // EXTERNAL DDR3
    // ========================================================
    //
    // 128 MiB reserved address space.
    //
    // Stage 1 does not connect a DDR3 controller.
    // Accesses remain unmapped until DDR3 integration.
    // ========================================================

    localparam cpu_pkg::word_t DDR3_BASE =
        cpu_pkg::word_t'(32'h8000_0000);

    localparam cpu_pkg::word_t DDR3_SIZE =
        cpu_pkg::word_t'(32'h0800_0000);

    localparam cpu_pkg::word_t DDR3_LIMIT =
        DDR3_BASE + DDR3_SIZE;

    // ========================================================
    // ADDRESS ALIGNMENT
    // ========================================================
    //
    // Stage 1 uses word-aligned addresses.
    //
    // Byte writes use an aligned word address together
    // with the appropriate write strobes.
    // ========================================================

    function automatic logic bus_is_aligned(
        input cpu_pkg::word_t addr
    );
        return (addr % cpu_pkg::WORD_BYTES) == 0;
    endfunction

    // ========================================================
    // WRITE-STROBE VALIDATION
    // ========================================================
    //
    // Reduction OR:
    //
    //     |wstrb
    //
    // Returns 1 when at least one byte is enabled.
    // ========================================================

    function automatic logic bus_has_write_bytes(
        input bus_strb_t wstrb
    );
        return |wstrb;
    endfunction

    // ========================================================
    // SUCCESS RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_success(
        input cpu_pkg::word_t rdata
    );

        bus_rsp_s rsp;

        rsp = '0;

        rsp.ready = 1'b1;
        rsp.rdata = rdata;
        rsp.error = 1'b0;

        return rsp;

    endfunction

    // ========================================================
    // ERROR RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_failure();

        bus_rsp_s rsp;

        rsp = '0;

        rsp.ready = 1'b1;
        rsp.rdata = '0;
        rsp.error = 1'b1;

        return rsp;

    endfunction

endpackage

`endif