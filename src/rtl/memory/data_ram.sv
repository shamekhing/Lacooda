`timescale 1ns/1ps
`ifndef DATA_RAM_SV
`define DATA_RAM_SV

// ============================================================
// Data memory
//
// LACOODA local data RAM.
//
// The data memory is a memory-bus slave.
//
// Memory organization:
//
//     CPU address:
//         byte address
//
//     RAM index:
//         word address
//
// At the fixed 32-bit configuration:
//
//     32 KiB
//     8192 x 32-bit words
//
// ------------------------------------------------------------
// ADDRESS RESPONSIBILITY
// ------------------------------------------------------------
//
// The address decoder/interconnect is responsible for deciding
// whether an address belongs to this memory region.
//
// Therefore data_ram does not repeat the global range check.
//
// If data_ram_req.valid reaches this module, the interconnect has
// already selected data memory.
//
// This module only checks whether the local byte address is
// correctly aligned to an architectural word.
//
// ------------------------------------------------------------
// RAM TIMING
// ------------------------------------------------------------
//
// Both reads and writes are synchronous.
//
// LOAD:
//
//     Cycle N:
//         valid = 1
//         ready = 0
//         address presented
//
//         rising edge:
//             memory word is captured
//
//     Cycle N+1:
//         ready = 1
//         rdata = captured word
//
// STORE:
//
//     Cycle N:
//         valid = 1
//         ready = 0
//         address + wdata presented
//
//         rising edge:
//             memory word is written
//
//     Cycle N+1:
//         ready = 1
//
// This structure is intentionally different from the previous
// asynchronous-read implementation so that the large memory
// can match a synchronous FPGA BSRAM inference pattern.
//
// ------------------------------------------------------------
// BUS PROTOCOL
// ------------------------------------------------------------
//
// A transaction completes when:
//
//     data_ram_req.valid && data_ram_rsp.ready
//
// The CPU holds its request stable while ready is low.
//
// Once ready is asserted, that request is complete.
//
// A new request may immediately follow on the next cycle;
// valid does NOT have to fall between transactions.
// ============================================================

module data_ram (
    input  logic              clk,
    input  logic              rst,

    input  bus_pkg::bus_req_s data_ram_req,
    output bus_pkg::bus_rsp_s data_ram_rsp
);


    // ========================================================
    // MEMORY ARRAY
    // ========================================================
    //
    // The array stores architectural words.
    //
    //     8192 x 32
    //
    // The synchronous access pattern below is intentional for
    // FPGA block-RAM inference.
    // ========================================================

    cpu_pkg::word_t ram_words [0 : memory_pkg::DATA_RAM_WORDS-1];

    // ========================================================
    // INITIALIZATION
    // ========================================================
    //
    // Do NOT initialize this RAM with:
    //
    //     for (...)
    //         ram_words[i] = '0;
    //
    // At 32 KiB that produces thousands of elaborated loop
    // iterations and previously hit Gowin's synthesis loop
    // limit.
    //
    // Instead the initial contents come from a hexadecimal
    // memory image.
    //
    // This does NOT make the RAM read-only.
    //
    // STORE instructions may overwrite the initialized values
    // normally after configuration.
    // ========================================================

    initial begin
        $readmemh(memory_pkg::DATA_RAM_INIT_FILE, ram_words);
    end


    // ========================================================
    // ADDRESS VALIDATION
    // ========================================================
    //
    // Range checking is NOT performed here.
    //
    // The address decoder/interconnect has already determined
    // that the request belongs to data memory.
    //
    // We only need to check word alignment.
    //
    //     WORD_BYTES = 4
    //
    //     valid:
    //         0x00000000
    //         0x00000004
    //         0x00000008
    //
    //     invalid:
    //         0x00000001
    //         0x00000002
    //         0x00000006
    //
    // WORD_BYTES is a compile-time constant, so synthesis can
    // simplify this operation.
    // ========================================================

    logic addr_valid;

    assign addr_valid =
        (data_ram_req.addr % cpu_pkg::WORD_BYTES) == 0;


    // ========================================================
    // REGISTERED READ RESULT
    // ========================================================
    //
    // This is the value returned by a LOAD.
    //
    // The important difference from the old implementation is
    // that this register is loaded inside always_ff:
    //
    //     read_data <= ram_words[index];
    //
    // rather than reading:
    //
    //     rdata = ram_words[index];
    //
    // combinationally.
    //
    // That makes the RAM read synchronous.
    // ========================================================

    cpu_pkg::word_t read_data;


    // ========================================================
    // RESPONSE PENDING
    // ========================================================
    //
    // pending = 0
    //
    //     Memory may accept a new request.
    //
    // pending = 1
    //
    //     The request accepted on the previous rising edge has
    //     completed and its response is available.
    //
    // data_ram_rsp.ready is generated from this state.
    // ========================================================

    logic pending;


    // ========================================================
    // SYNCHRONOUS MEMORY ACCESS
    // ========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            // ------------------------------------------------
            // Reset interface state only.
            //
            // DO NOT reset the complete memory array here.
            //
            // A reset loop over thousands of memory words can
            // prevent efficient block-RAM inference and would
            // require the physical RAM to support runtime
            // clearing behavior that we do not need.
            //
            // RAM initialization is handled by $readmemh.
            // ------------------------------------------------

            pending   <= 1'b0;
            read_data <= '0;

        end
        else begin

            // ------------------------------------------------
            // A pending response is consumed when:
            //
            //     valid && ready
            //
            // Since ready == pending, a held valid request
            // completes here.
            //
            // Clear pending by default.
            // ------------------------------------------------

            pending <= 1'b0;


            // ------------------------------------------------
            // Accept a new request only when there is no
            // previous response waiting.
            // ------------------------------------------------

            if (data_ram_req.valid && !pending) begin
                // --------------------------------------------
                // The request will receive a response during
                // the following cycle.
                // --------------------------------------------
                pending <= 1'b1;

                // ============================================
                // ALIGNED ACCESS
                // ============================================

                if (addr_valid) begin

                    // ----------------------------------------
                    // STORE
                    //
                    // Because this assignment occurs inside
                    // always_ff @(posedge clk), the memory
                    // write is synchronous.
                    // ----------------------------------------

                    if (data_ram_req.op == bus_pkg::BUS_WRITE) begin

                        ram_words[
                            data_ram_req.addr
                            / cpu_pkg::WORD_BYTES
                        ] <= data_ram_req.wdata;

                    end


                    // ----------------------------------------
                    // LOAD
                    //
                    // The selected memory word is captured at
                    // the rising edge.
                    //
                    // read_data then remains stable during the
                    // response cycle while ready is asserted.
                    // ----------------------------------------

                    else begin

                        read_data <= ram_words[
                            data_ram_req.addr
                            / cpu_pkg::WORD_BYTES
                        ];

                    end

                end


                // ============================================
                // MISALIGNED ACCESS
                // ============================================

                else begin

                    // ----------------------------------------
                    // Misaligned LOAD:
                    //
                    //     complete normally
                    //     return zero
                    //
                    // Misaligned STORE:
                    //
                    //     complete normally
                    //     perform no write
                    //
                    // This preserves the existing simple
                    // "invalid access does nothing" policy.
                    // ----------------------------------------

                    read_data <= '0;

                end

            end

        end

    end


    // ========================================================
    // BUS RESPONSE
    // ========================================================
    //
    // pending becomes 1 after a request has been processed at
    // a rising edge.
    //
    // Therefore:
    //
    //     pending = 0 -> ready = 0
    //
    //     pending = 1 -> ready = 1
    //
    // For LOAD, read_data contains the synchronously captured
    // memory word.
    //
    // For STORE, rdata is irrelevant to the CPU.
    // ========================================================

    always_comb begin

        data_ram_rsp.ready = pending;
        data_ram_rsp.rdata = read_data;

    end


endmodule

`endif
