`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

// ============================================================
// LACOODA NATIVE BUS PROTOCOL PACKAGE — STAGE 5
// ============================================================
//
// Protocol only. The SoC memory map and routing policy now
// live in rpu_pkg.sv.
//
// Conventions:
//   - 32-bit native words
//   - Byte-addressed locations
//   - Word-aligned native accesses
//   - One outstanding transaction per master
//
// Completion occurs on a rising clock edge with:
//   request.valid && response.ready
//
// A master must hold its request stable until completion.
//
// No $fatal, $display, or other simulation tasks appear in
// this synthesizable package.
// ============================================================

package bus_pkg;

    // ========================================================
    // OPERATIONS
    // ========================================================

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_e;

    // ========================================================
    // WRITE STROBES
    // ========================================================
    //
    // Strobe bit n enables byte n of wdata.
    // ========================================================

    typedef logic [cpu_pkg::WORD_BYTES-1:0] bus_strb_t;

    localparam bus_strb_t BUS_STRB_NONE = '0;
    localparam bus_strb_t BUS_STRB_ALL  = '1;

    // ========================================================
    // REQUEST AND RESPONSE
    // ========================================================

    typedef struct packed {
        logic           valid;
        bus_op_e        op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;
        bus_strb_t      wstrb;
    } bus_req_s;

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
        logic           error;
    } bus_rsp_s;

    // ========================================================
    // ALIGNMENT
    // ========================================================

    function automatic logic bus_is_aligned(
        input cpu_pkg::word_t addr
    );

        return (addr % cpu_pkg::WORD_BYTES) == 0;

    endfunction

    // ========================================================
    // WRITE BYTE VALIDITY
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

        bus_rsp_s result;

        result = '0;
        result.ready = 1'b1;
        result.rdata = rdata;
        result.error = 1'b0;

        return result;

    endfunction

    // ========================================================
    // ERROR RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_failure();

        bus_rsp_s result;

        result = '0;
        result.ready = 1'b1;
        result.rdata = '0;
        result.error = 1'b1;

        return result;

    endfunction

endpackage

`endif
