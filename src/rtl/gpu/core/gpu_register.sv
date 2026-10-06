`timescale 1ns/1ps

// ============================================================
// LACOODA GPU register block
//
// CPU-visible GPU MMIO register bank.
//
// This module is a direct LACOODA bus slave.
//
// Input:
//
//     bus_pkg::bus_req_s
//
// Output:
//
//     bus_pkg::bus_rsp_s
//
// The bus interconnect has already:
//
//     1. determined that the address belongs to the GPU
//     2. subtracted bus_pkg::GPU_BASE
//
// Therefore slave_req.addr is already a GPU-local byte address.
//
// Responsibilities:
//
//     - decode GPU register addresses
//     - store CPU-writable GPU configuration
//     - expose read-only GPU status
//     - generate the bus response
//
// Not responsible for:
//
//     - rendering
//     - rasterization
//     - framebuffer memory
//     - command execution
//     - display output
//
// Those belong to later GPU stages.
// ============================================================

module gpu_register (
    input logic clk,
    input logic rst,

    // --------------------------------------------------------
    // LACOODA slave bus
    // --------------------------------------------------------

    input  bus_pkg::bus_req_s slave_req,
    output bus_pkg::bus_rsp_s slave_rsp,

    // --------------------------------------------------------
    // GPU internal state
    // --------------------------------------------------------

    input gpu_pkg::gpu_status_s status,

    output gpu_pkg::gpu_config_s gpu_cfg
);


    // ========================================================
    // LOCAL ADDRESS
    // ========================================================

    gpu_pkg::gpu_addr_t local_addr;

    assign local_addr = gpu_pkg::gpu_addr_t'(
            slave_req.addr
        );


    // ========================================================
    // CONFIGURATION REGISTER WRITE
    // ========================================================
    //
    // All writable GPU registers are stored inside gpu_cfg.
    //
    // ID and STATUS are not stored here because they are
    // read-only.
    //
    // Reserved register addresses simply ignore writes.
    // ========================================================

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            gpu_cfg <= '0;

        end else if (
            slave_req.valid && (slave_req.op == bus_pkg::BUS_WRITE)
        ) begin

            case (local_addr)

                // --------------------------------------------
                // CONTROL
                // --------------------------------------------

                gpu_pkg::GPU_REG_CONTROL: begin

                    gpu_cfg.control <=
                        slave_req.wdata;

                end


                // --------------------------------------------
                // FRAMEBUFFER BASE
                // --------------------------------------------

                gpu_pkg::GPU_REG_FRAMEBUFFER_BASE: begin

                    gpu_cfg.framebuffer_base <=
                        slave_req.wdata;

                end


                // --------------------------------------------
                // FRAMEBUFFER WIDTH
                // --------------------------------------------

                gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH: begin

                    gpu_cfg.framebuffer_width <=
                        slave_req.wdata;

                end


                // --------------------------------------------
                // FRAMEBUFFER HEIGHT
                // --------------------------------------------

                gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT: begin

                    gpu_cfg.framebuffer_height <=
                        slave_req.wdata;

                end


                // --------------------------------------------
                // CLEAR COLOR
                // --------------------------------------------

                gpu_pkg::GPU_REG_CLEAR_COLOR: begin

                    gpu_cfg.clear_color <=
                        slave_req.wdata;

                end


                // --------------------------------------------
                // READ-ONLY / RESERVED
                // --------------------------------------------

                default: begin

                    // GPU_REG_ID:
                    //     read-only
                    //
                    // GPU_REG_STATUS:
                    //     read-only
                    //
                    // Unknown addresses:
                    //     ignored

                end

            endcase

        end

    end


    // ========================================================
    // BUS READ RESPONSE
    // ========================================================
    //
    // MMIO registers currently have no wait states.
    //
    // Therefore every valid GPU request completes immediately.
    //
    // Reserved addresses:
    //
    //     READ  -> zero
    //     WRITE -> ignored
    //
    // This matches the simple invalid-access behavior already
    // used elsewhere in the current LACOODA system.
    // ========================================================

    always_comb begin

        slave_rsp = '0;


        // ----------------------------------------------------
        // VALID REQUEST
        // ----------------------------------------------------

        if (slave_req.valid) begin

            slave_rsp.ready =
                1'b1;


            // ------------------------------------------------
            // READ
            // ------------------------------------------------

            if (
                slave_req.op ==
                bus_pkg::BUS_READ
            ) begin

                case (local_addr)


                    // ========================================
                    // ID
                    // ========================================

                    gpu_pkg::GPU_REG_ID: begin

                        slave_rsp.rdata =
                            gpu_pkg::GPU_ID_VALUE;

                    end


                    // ========================================
                    // CONTROL
                    // ========================================

                    gpu_pkg::GPU_REG_CONTROL: begin

                        slave_rsp.rdata =
                            gpu_cfg.control;

                    end


                    // ========================================
                    // STATUS
                    // ========================================

                    gpu_pkg::GPU_REG_STATUS: begin

                        slave_rsp.rdata =
                            cpu_pkg::word_t'(
                                status
                            );

                    end


                    // ========================================
                    // FRAMEBUFFER BASE
                    // ========================================

                    gpu_pkg::GPU_REG_FRAMEBUFFER_BASE: begin

                        slave_rsp.rdata =
                            gpu_cfg.framebuffer_base;

                    end


                    // ========================================
                    // FRAMEBUFFER WIDTH
                    // ========================================

                    gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH: begin

                        slave_rsp.rdata =
                            gpu_cfg.framebuffer_width;

                    end


                    // ========================================
                    // FRAMEBUFFER HEIGHT
                    // ========================================

                    gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT: begin

                        slave_rsp.rdata =
                            gpu_cfg.framebuffer_height;

                    end


                    // ========================================
                    // CLEAR COLOR
                    // ========================================

                    gpu_pkg::GPU_REG_CLEAR_COLOR: begin

                        slave_rsp.rdata =
                            gpu_cfg.clear_color;

                    end


                    // ========================================
                    // RESERVED
                    // ========================================

                    default: begin

                        slave_rsp.rdata =
                            '0;

                    end

                endcase

            end

        end

    end

endmodule