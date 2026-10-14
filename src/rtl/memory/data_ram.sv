`timescale 1ns/1ps
`ifndef DATA_RAM_SV
`define DATA_RAM_SV

// ============================================================
// LACOODA SYNCHRONOUS DATA RAM
// ============================================================
//
// 32 KiB, organized as 8192 x 32-bit words.
//
// Features:
//   - Synchronous read
//   - Synchronous write
//   - Byte write enables
//   - Registered response
//   - Address alignment validation
//   - Local address range validation
//   - Error reporting
//
// The RAM array is not reset.
//
// Initialization uses the existing memory image.
//
// TRANSACTION TIMING:
//
//   Cycle N:
//       valid = 1
//       ready = 0
//
//   Rising edge:
//       Read or write executes.
//
//   Cycle N+1:
//       ready = 1
//       Read data and error status are valid.
//
//   Next rising edge:
//       Transaction completes.
//
// The master must hold its request until completion.
//
// The RAM does not accept a second transaction while a
// response is pending.
//
// This implementation is intentionally non-pipelined.
// ============================================================

module data_ram (

    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s data_ram_req,
    output bus_pkg::bus_rsp_s data_ram_rsp

);

    // ========================================================
    // MEMORY ARRAY
    // ========================================================

    cpu_pkg::word_t ram_words [
        0 : memory_pkg::DATA_RAM_WORDS-1
    ];

    // ========================================================
    // INITIAL MEMORY CONTENTS
    // ========================================================
    //
    // No reset loop is used.
    //
    // A large reset loop would interfere with efficient
    // FPGA block RAM inference.
    // ========================================================

    initial begin

        $readmemh(
            memory_pkg::DATA_RAM_INIT_FILE,
            ram_words
        );

    end

    // ========================================================
    // ADDRESS VALIDATION
    // ========================================================

    localparam int RAM_INDEX_WIDTH =
        $clog2(memory_pkg::DATA_RAM_WORDS);

    localparam cpu_pkg::word_t RAM_SIZE_BYTES =
        cpu_pkg::word_t'(memory_pkg::DATA_RAM_WORDS)
        * cpu_pkg::word_t'(cpu_pkg::WORD_BYTES);

    logic addr_aligned;
    logic addr_in_range;
    logic addr_valid;

    logic [RAM_INDEX_WIDTH-1:0] word_index;

    assign addr_aligned =
        bus_pkg::bus_is_aligned(data_ram_req.addr);

    assign addr_in_range =
        data_ram_req.addr < RAM_SIZE_BYTES;

    assign addr_valid =
        addr_aligned && addr_in_range;

    // Divide byte address by four to obtain word index.
    //
    // Division by a power-of-two constant synthesizes
    // as a shift or bit selection.

    assign word_index =
        RAM_INDEX_WIDTH'(
            data_ram_req.addr / cpu_pkg::WORD_BYTES
        );

    // ========================================================
    // RESPONSE REGISTERS
    // ========================================================

    logic pending;
    logic response_error;

    cpu_pkg::word_t read_data;

    // ========================================================
    // SYNCHRONOUS TRANSACTION PROCESSING
    // ========================================================
    //
    // pending = 0:
    //   May accept a request.
    //
    // pending = 1:
    //   Response is available.
    //   No additional memory operation is executed.
    //
    // Both pending and read_data update after the same
    // rising edge through nonblocking assignments.
    //
    // Therefore ready is not asserted before read_data
    // has been captured.
    // ========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            pending        <= 1'b0;
            response_error <= 1'b0;
            read_data      <= '0;

        end else if (pending) begin

            // ------------------------------------------------
            // COMPLETE PREVIOUS TRANSACTION
            // ------------------------------------------------
            //
            // The master observes ready = 1 before this edge.
            //
            // At this edge the handshake completes.
            //
            // Return to the request-acceptance state.
            // ------------------------------------------------

            pending <= 1'b0;

        end else if (data_ram_req.valid) begin

            // ------------------------------------------------
            // ACCEPT NEW TRANSACTION
            // ------------------------------------------------

            pending <= 1'b1;

            response_error <= !addr_valid;

            // ------------------------------------------------
            // INVALID ADDRESS
            // ------------------------------------------------
            //
            // Do not access memory.
            // Return an error response.
            // ------------------------------------------------

            if (!addr_valid) begin

                read_data <= '0;

            end

            // ------------------------------------------------
            // WRITE
            // ------------------------------------------------
            //
            // Update only enabled bytes.
            //
            // The write executes once at this edge.
            // ------------------------------------------------

            else if (
                data_ram_req.op == bus_pkg::BUS_WRITE
            ) begin

                for (
                    int byte_index = 0;
                    byte_index < cpu_pkg::WORD_BYTES;
                    byte_index++
                ) begin

                    if (data_ram_req.wstrb[byte_index]) begin

                        ram_words[word_index]
                            [8*byte_index +: 8]
                            <=
                            data_ram_req.wdata
                            [8*byte_index +: 8];

                    end

                end

                read_data <= '0;

            end

            // ------------------------------------------------
            // READ
            // ------------------------------------------------
            //
            // Synchronous read.
            //
            // The selected word is captured at this edge.
            // ------------------------------------------------

            else begin

                read_data <= ram_words[word_index];

            end

        end

    end

    // ========================================================
    // RESPONSE
    // ========================================================

    always_comb begin

        data_ram_rsp = '0;

        if (!rst && pending) begin

            data_ram_rsp.ready = 1'b1;
            data_ram_rsp.rdata = read_data;
            data_ram_rsp.error = response_error;

        end

    end

endmodule

`endif