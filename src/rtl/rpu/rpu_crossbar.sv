`timescale 1ns/1ps

// ============================================================
// LACOODA RPU CROSSBAR — STAGE 5
// ============================================================
//
// Fixed 4 x 4 routing fabric.
//
//   m0 : CPU instruction fetch
//   m1 : CPU data
//   m2 : GPU memory master
//   m3 : TPU memory master
//
//   s0 : instruction ROM
//   s1 : internal data RAM
//   s2 : GPU MMIO
//   s3 : DDR3 bridge
//
// The explicit port lists are deliberate. Icarus Verilog 12
// cannot elaborate unpacked-array parameters, 2D arrays, or
// array slices, so the generic N x M form is expressed as a
// fixed 4 x 4 fabric. Extending the fabric means extending
// these lists and the routing policy in rpu_pkg.sv.
//
// A master request is forwarded to at most one slave port.
// Each slave port arbitrates independently, so transactions
// to different slaves proceed in parallel.
//
// CAPABILITY-AWARE ADMISSION
//
//   Each slave port has one operation slot, matching the actual
//   capability of the existing ROM, RAM, GPU MMIO and DDR3
//   bridge. A transaction is admitted only when that slot is
//   free. A busy slave cannot block a different slave, and no
//   illegal simultaneous read/write combination can be admitted
//   because the slot accepts one operation at a time.
//
// Invalid, unaligned, or reserved accesses receive an
// immediate error response and generate no slave traffic.
// ============================================================

module rpu_crossbar (

    input logic clk,
    input logic rst,

    // --------------------------------------------------------
    // MASTERS
    // --------------------------------------------------------

    input  bus_pkg::bus_req_s m0_req,
    output bus_pkg::bus_rsp_s m0_rsp,

    input  bus_pkg::bus_req_s m1_req,
    output bus_pkg::bus_rsp_s m1_rsp,

    input  bus_pkg::bus_req_s m2_req,
    output bus_pkg::bus_rsp_s m2_rsp,

    input  bus_pkg::bus_req_s m3_req,
    output bus_pkg::bus_rsp_s m3_rsp,

    // --------------------------------------------------------
    // SLAVES
    // --------------------------------------------------------

    output bus_pkg::bus_req_s s0_req,
    input  bus_pkg::bus_rsp_s s0_rsp,

    output bus_pkg::bus_req_s s1_req,
    input  bus_pkg::bus_rsp_s s1_rsp,

    output bus_pkg::bus_req_s s2_req,
    input  bus_pkg::bus_rsp_s s2_rsp,

    output bus_pkg::bus_req_s s3_req,
    input  bus_pkg::bus_rsp_s s3_rsp,

    // --------------------------------------------------------
    // OBSERVABILITY
    // --------------------------------------------------------

    output logic [3:0] master_pending,
    output logic [3:0] slave_active

);

    // ========================================================
    // DECODED ROUTES
    // ========================================================

    rpu_pkg::rpu_route_s m0_route;
    rpu_pkg::rpu_route_s m1_route;
    rpu_pkg::rpu_route_s m2_route;
    rpu_pkg::rpu_route_s m3_route;

    rpu_decoder u_decoder (
        .cpu_i_addr (m0_req.addr),
        .cpu_d_addr (m1_req.addr),
        .gpu_addr   (m2_req.addr),
        .tpu_addr   (m3_req.addr),
        .cpu_i_route(m0_route),
        .cpu_d_route(m1_route),
        .gpu_route  (m2_route),
        .tpu_route  (m3_route)
    );

    // ========================================================
    // ALIGNMENT
    // ========================================================

    logic m0_aligned;
    logic m1_aligned;
    logic m2_aligned;
    logic m3_aligned;

    assign m0_aligned = (m0_req.addr % cpu_pkg::WORD_BYTES) == 0;
    assign m1_aligned = (m1_req.addr % cpu_pkg::WORD_BYTES) == 0;
    assign m2_aligned = (m2_req.addr % cpu_pkg::WORD_BYTES) == 0;
    assign m3_aligned = (m3_req.addr % cpu_pkg::WORD_BYTES) == 0;

    // ========================================================
    // REQUEST MATRIX SIGNALS
    // ========================================================
    //
    // Each slave port has four dedicated request inputs.
    // A request is driven only when its master is valid,
    // aligned, and routed to that slave. The address is
    // translated to the slave-local address.
    // ========================================================

    bus_pkg::bus_req_s s0_from_m0;
    bus_pkg::bus_req_s s0_from_m1;
    bus_pkg::bus_req_s s0_from_m2;
    bus_pkg::bus_req_s s0_from_m3;

    bus_pkg::bus_req_s s1_from_m0;
    bus_pkg::bus_req_s s1_from_m1;
    bus_pkg::bus_req_s s1_from_m2;
    bus_pkg::bus_req_s s1_from_m3;

    bus_pkg::bus_req_s s2_from_m0;
    bus_pkg::bus_req_s s2_from_m1;
    bus_pkg::bus_req_s s2_from_m2;
    bus_pkg::bus_req_s s2_from_m3;

    bus_pkg::bus_req_s s3_from_m0;
    bus_pkg::bus_req_s s3_from_m1;
    bus_pkg::bus_req_s s3_from_m2;
    bus_pkg::bus_req_s s3_from_m3;

    // --------------------------------------------------------
    // MASTER 0 (CPU instruction fetch)
    // --------------------------------------------------------

    always_comb begin

        s0_from_m0 = '0;
        s1_from_m0 = '0;
        s2_from_m0 = '0;
        s3_from_m0 = '0;

        if (m0_req.valid && m0_aligned && m0_route.valid) begin

            case (m0_route.slave)
                rpu_pkg::RPU_S_ROM: begin
                    s0_from_m0 = m0_req;
                    s0_from_m0.addr = m0_route.local_addr;
                end
                rpu_pkg::RPU_S_DATA_RAM: begin
                    s1_from_m0 = m0_req;
                    s1_from_m0.addr = m0_route.local_addr;
                end
                rpu_pkg::RPU_S_GPU_MMIO: begin
                    s2_from_m0 = m0_req;
                    s2_from_m0.addr = m0_route.local_addr;
                end
                rpu_pkg::RPU_S_DDR3: begin
                    s3_from_m0 = m0_req;
                    s3_from_m0.addr = m0_route.local_addr;
                end
                default: ;
            endcase

        end

    end

    // --------------------------------------------------------
    // MASTER 1 (CPU data)
    // --------------------------------------------------------

    always_comb begin

        s0_from_m1 = '0;
        s1_from_m1 = '0;
        s2_from_m1 = '0;
        s3_from_m1 = '0;

        if (m1_req.valid && m1_aligned && m1_route.valid) begin

            case (m1_route.slave)
                rpu_pkg::RPU_S_ROM: begin
                    s0_from_m1 = m1_req;
                    s0_from_m1.addr = m1_route.local_addr;
                end
                rpu_pkg::RPU_S_DATA_RAM: begin
                    s1_from_m1 = m1_req;
                    s1_from_m1.addr = m1_route.local_addr;
                end
                rpu_pkg::RPU_S_GPU_MMIO: begin
                    s2_from_m1 = m1_req;
                    s2_from_m1.addr = m1_route.local_addr;
                end
                rpu_pkg::RPU_S_DDR3: begin
                    s3_from_m1 = m1_req;
                    s3_from_m1.addr = m1_route.local_addr;
                end
                default: ;
            endcase

        end

    end


    // --------------------------------------------------------
    // MASTER 2 (GPU memory master)
    // --------------------------------------------------------

    always_comb begin

        s0_from_m2 = '0;
        s1_from_m2 = '0;
        s2_from_m2 = '0;
        s3_from_m2 = '0;

        if (m2_req.valid && m2_aligned && m2_route.valid) begin

            case (m2_route.slave)
                rpu_pkg::RPU_S_ROM: begin
                    s0_from_m2 = m2_req;
                    s0_from_m2.addr = m2_route.local_addr;
                end
                rpu_pkg::RPU_S_DATA_RAM: begin
                    s1_from_m2 = m2_req;
                    s1_from_m2.addr = m2_route.local_addr;
                end
                rpu_pkg::RPU_S_GPU_MMIO: begin
                    s2_from_m2 = m2_req;
                    s2_from_m2.addr = m2_route.local_addr;
                end
                rpu_pkg::RPU_S_DDR3: begin
                    s3_from_m2 = m2_req;
                    s3_from_m2.addr = m2_route.local_addr;
                end
                default: ;
            endcase

        end

    end

    // --------------------------------------------------------
    // MASTER 3 (TPU memory master)
    // --------------------------------------------------------

    always_comb begin

        s0_from_m3 = '0;
        s1_from_m3 = '0;
        s2_from_m3 = '0;
        s3_from_m3 = '0;

        if (m3_req.valid && m3_aligned && m3_route.valid) begin

            case (m3_route.slave)
                rpu_pkg::RPU_S_ROM: begin
                    s0_from_m3 = m3_req;
                    s0_from_m3.addr = m3_route.local_addr;
                end
                rpu_pkg::RPU_S_DATA_RAM: begin
                    s1_from_m3 = m3_req;
                    s1_from_m3.addr = m3_route.local_addr;
                end
                rpu_pkg::RPU_S_GPU_MMIO: begin
                    s2_from_m3 = m3_req;
                    s2_from_m3.addr = m3_route.local_addr;
                end
                rpu_pkg::RPU_S_DDR3: begin
                    s3_from_m3 = m3_req;
                    s3_from_m3.addr = m3_route.local_addr;
                end
                default: ;
            endcase

        end

    end


    // ========================================================
    // RESPONSE MATRIX SIGNALS
    // ========================================================

    bus_pkg::bus_rsp_s s0_to_m0;
    bus_pkg::bus_rsp_s s0_to_m1;
    bus_pkg::bus_rsp_s s0_to_m2;
    bus_pkg::bus_rsp_s s0_to_m3;

    bus_pkg::bus_rsp_s s1_to_m0;
    bus_pkg::bus_rsp_s s1_to_m1;
    bus_pkg::bus_rsp_s s1_to_m2;
    bus_pkg::bus_rsp_s s1_to_m3;

    bus_pkg::bus_rsp_s s2_to_m0;
    bus_pkg::bus_rsp_s s2_to_m1;
    bus_pkg::bus_rsp_s s2_to_m2;
    bus_pkg::bus_rsp_s s2_to_m3;

    bus_pkg::bus_rsp_s s3_to_m0;
    bus_pkg::bus_rsp_s s3_to_m1;
    bus_pkg::bus_rsp_s s3_to_m2;
    bus_pkg::bus_rsp_s s3_to_m3;

    // ========================================================
    // SLAVE PORTS
    // ========================================================

    rpu_slave_port u_slave_rom (
        .clk(clk),
        .rst(rst),
        .req0(s0_from_m0),
        .req1(s0_from_m1),
        .req2(s0_from_m2),
        .req3(s0_from_m3),
        .rsp0(s0_to_m0),
        .rsp1(s0_to_m1),
        .rsp2(s0_to_m2),
        .rsp3(s0_to_m3),
        .slave_req(s0_req),
        .slave_rsp(s0_rsp),
        .owner_active(slave_active[0])
    );

    rpu_slave_port u_slave_ram (
        .clk(clk),
        .rst(rst),
        .req0(s1_from_m0),
        .req1(s1_from_m1),
        .req2(s1_from_m2),
        .req3(s1_from_m3),
        .rsp0(s1_to_m0),
        .rsp1(s1_to_m1),
        .rsp2(s1_to_m2),
        .rsp3(s1_to_m3),
        .slave_req(s1_req),
        .slave_rsp(s1_rsp),
        .owner_active(slave_active[1])
    );

    rpu_slave_port u_slave_gpu (
        .clk(clk),
        .rst(rst),
        .req0(s2_from_m0),
        .req1(s2_from_m1),
        .req2(s2_from_m2),
        .req3(s2_from_m3),
        .rsp0(s2_to_m0),
        .rsp1(s2_to_m1),
        .rsp2(s2_to_m2),
        .rsp3(s2_to_m3),
        .slave_req(s2_req),
        .slave_rsp(s2_rsp),
        .owner_active(slave_active[2])
    );

    rpu_slave_port u_slave_ddr3 (
        .clk(clk),
        .rst(rst),
        .req0(s3_from_m0),
        .req1(s3_from_m1),
        .req2(s3_from_m2),
        .req3(s3_from_m3),
        .rsp0(s3_to_m0),
        .rsp1(s3_to_m1),
        .rsp2(s3_to_m2),
        .rsp3(s3_to_m3),
        .slave_req(s3_req),
        .slave_rsp(s3_rsp),
        .owner_active(slave_active[3])
    );


    // ========================================================
    // RESPONSE MULTIPLEXERS
    // ========================================================
    //
    // Only the slave selected by the master's decoded route
    // can drive that master's response. An invalid, reserved,
    // or unaligned access receives an immediate error.
    // ========================================================

    // --------------------------------------------------------
    // MASTER 0 (CPU instruction fetch)
    // --------------------------------------------------------

    always_comb begin

        m0_rsp = '0;

        if (!rst && m0_req.valid) begin

            if (!m0_aligned || !m0_route.valid) begin

                m0_rsp.ready = 1'b1;
                m0_rsp.rdata = '0;
                m0_rsp.error = 1'b1;

            end else begin

                case (m0_route.slave)
                    rpu_pkg::RPU_S_ROM:      m0_rsp = s0_to_m0;
                    rpu_pkg::RPU_S_DATA_RAM: m0_rsp = s1_to_m0;
                    rpu_pkg::RPU_S_GPU_MMIO: m0_rsp = s2_to_m0;
                    rpu_pkg::RPU_S_DDR3:     m0_rsp = s3_to_m0;
                    default: begin
                        m0_rsp.ready = 1'b1;
                        m0_rsp.rdata = '0;
                        m0_rsp.error = 1'b1;
                    end
                endcase

            end

        end

    end

    // --------------------------------------------------------
    // MASTER 1 (CPU data)
    // --------------------------------------------------------

    always_comb begin

        m1_rsp = '0;

        if (!rst && m1_req.valid) begin

            if (!m1_aligned || !m1_route.valid) begin

                m1_rsp.ready = 1'b1;
                m1_rsp.rdata = '0;
                m1_rsp.error = 1'b1;

            end else begin

                case (m1_route.slave)
                    rpu_pkg::RPU_S_ROM:      m1_rsp = s0_to_m1;
                    rpu_pkg::RPU_S_DATA_RAM: m1_rsp = s1_to_m1;
                    rpu_pkg::RPU_S_GPU_MMIO: m1_rsp = s2_to_m1;
                    rpu_pkg::RPU_S_DDR3:     m1_rsp = s3_to_m1;
                    default: begin
                        m1_rsp.ready = 1'b1;
                        m1_rsp.rdata = '0;
                        m1_rsp.error = 1'b1;
                    end
                endcase

            end

        end

    end


    // --------------------------------------------------------
    // MASTER 2 (GPU memory master)
    // --------------------------------------------------------

    always_comb begin

        m2_rsp = '0;

        if (!rst && m2_req.valid) begin

            if (!m2_aligned || !m2_route.valid) begin

                m2_rsp.ready = 1'b1;
                m2_rsp.rdata = '0;
                m2_rsp.error = 1'b1;

            end else begin

                case (m2_route.slave)
                    rpu_pkg::RPU_S_ROM:      m2_rsp = s0_to_m2;
                    rpu_pkg::RPU_S_DATA_RAM: m2_rsp = s1_to_m2;
                    rpu_pkg::RPU_S_GPU_MMIO: m2_rsp = s2_to_m2;
                    rpu_pkg::RPU_S_DDR3:     m2_rsp = s3_to_m2;
                    default: begin
                        m2_rsp.ready = 1'b1;
                        m2_rsp.rdata = '0;
                        m2_rsp.error = 1'b1;
                    end
                endcase

            end

        end

    end

    // --------------------------------------------------------
    // MASTER 3 (TPU memory master)
    // --------------------------------------------------------

    always_comb begin

        m3_rsp = '0;

        if (!rst && m3_req.valid) begin

            if (!m3_aligned || !m3_route.valid) begin

                m3_rsp.ready = 1'b1;
                m3_rsp.rdata = '0;
                m3_rsp.error = 1'b1;

            end else begin

                case (m3_route.slave)
                    rpu_pkg::RPU_S_ROM:      m3_rsp = s0_to_m3;
                    rpu_pkg::RPU_S_DATA_RAM: m3_rsp = s1_to_m3;
                    rpu_pkg::RPU_S_GPU_MMIO: m3_rsp = s2_to_m3;
                    rpu_pkg::RPU_S_DDR3:     m3_rsp = s3_to_m3;
                    default: begin
                        m3_rsp.ready = 1'b1;
                        m3_rsp.rdata = '0;
                        m3_rsp.error = 1'b1;
                    end
                endcase

            end

        end

    end

    // ========================================================
    // OBSERVABILITY
    // ========================================================

    assign master_pending = {
        m3_req.valid,
        m2_req.valid,
        m1_req.valid,
        m0_req.valid
    };

endmodule
