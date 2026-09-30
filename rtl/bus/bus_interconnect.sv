`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus interconnect
//
// One CPU data-bus master is routed to the currently implemented local
// data-memory slave. This module owns address selection and response
// routing; neither the CPU nor the memory needs to know about the other.
//
// Protocol:
//   - Master holds valid/address/write/write_data until ready.
//   - Selected slave receives the request.
//   - Slave ready/read_data are returned to the master.
//   - Unmapped accesses complete immediately with read_data=0. This keeps
//     the Stage-7 behavior where invalid accesses do not deadlock the CPU.
// ============================================================

module bus_interconnect (
    // CPU/master side.
    input  logic           master_valid,
    input  logic           master_write,
    input  cpu_pkg::data_t master_address,
    input  cpu_pkg::data_t master_write_data,
    output logic           master_ready,
    output cpu_pkg::data_t master_read_data,

    // Local data-memory slave side.
    output logic           data_memory_valid,
    output logic           data_memory_write,
    output cpu_pkg::data_t data_memory_address,
    output cpu_pkg::data_t data_memory_write_data,
    input  logic           data_memory_ready,
    input  cpu_pkg::data_t data_memory_read_data
);

    logic data_memory_select;

    address_decoder u_address_decoder (
        .address            (master_address),
        .data_memory_select (data_memory_select)
    );

    // Requests are forwarded only to the selected slave. The address
    // presented to the slave is local to its mapped region.
    assign data_memory_valid = master_valid && data_memory_select;
    assign data_memory_write = master_write;
    assign data_memory_address = master_address - bus_pkg::DATA_MEMORY_BASE;
    assign data_memory_write_data = master_write_data;

    always_comb begin
        master_ready = 1'b0;
        master_read_data = '0;

        if (master_valid) begin
            if (data_memory_select) begin
                master_ready = data_memory_ready;
                master_read_data = data_memory_read_data;
            end else begin
                // Preserve the existing no-fault Stage-7 behavior for an
                // unmapped address: complete the request and return zero.
                master_ready = 1'b1;
                master_read_data = '0;
            end
        end
    end

endmodule
