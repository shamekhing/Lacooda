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
    input  logic           dbus_valid,
    input  logic           dbus_write,
    input  cpu_pkg::reg_t dbus_address,
    input  cpu_pkg::data_memory_t dbus_write_data,
    output logic           dbus_ready,
    output cpu_pkg::data_memory_t dbus_read_data,

    // Local data-memory slave side.
    output logic           slave_valid,
    output logic           slave_write,
    output cpu_pkg::reg_t slave_address,
    output cpu_pkg::data_memory_t slave_write_data,
    input  logic           slave_ready,
    input  cpu_pkg::data_memory_t slave_read_data
);

    logic slave_select;

    address_decoder u_address_decoder (
        .address      (dbus_address),
        .slave_select (slave_select)
    );

    // Requests are forwarded only to the selected slave. The address
    // presented to the slave is local to its mapped region.
    assign slave_valid = dbus_valid && slave_select;
    assign slave_write = dbus_write;
    assign slave_address = dbus_address - bus_pkg::DATA_MEMORY_BASE;
    assign slave_write_data = dbus_write_data;

    always_comb begin
        dbus_ready = 1'b0;
        dbus_read_data = '0;

        if (dbus_valid) begin
            if (slave_select) begin
                dbus_ready = slave_ready;
                dbus_read_data = slave_read_data;
            end else begin
                // Preserve the existing no-fault Stage-7 behavior for an
                // unmapped address: complete the request and return zero.
                dbus_ready = 1'b1;
                dbus_read_data = '0;
            end
        end
    end

endmodule
