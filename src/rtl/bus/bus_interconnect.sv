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
    input  bus_pkg::bus_req_s  d_req,
    output bus_pkg::bus_rsp_s  d_rsp,
    output bus_pkg::bus_req_s  slave_req,
    input  bus_pkg::bus_rsp_s  slave_rsp
);

    logic slave_sel;

    address_cpu_decoder u_address_cpu_decoder (
        .addr      (d_req.addr),
        .slave_sel (slave_sel)
    );

    // Requests are forwarded only to the selected slave. The address
    // presented to the slave is local to its mapped region.
    assign slave_req.valid = d_req.valid && slave_sel;
    assign slave_req.op = d_req.op;
    assign slave_req.addr = d_req.addr - bus_pkg::DATA_MEMORY_BASE;
    assign slave_req.wdata = d_req.wdata;

    always_comb begin
        d_rsp = '0;

        if (d_req.valid) begin
            if (slave_sel) begin
                d_rsp = slave_rsp;
            end else begin
                // Preserve the existing no-fault Stage-7 behavior for an
                // unmapped address: complete the request and return zero.
                d_rsp.ready = 1'b1;
            end
        end
    end

endmodule
