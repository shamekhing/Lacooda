`timescale 1ns/1ps

// ============================================================
// LACOODA GPU memory interface
//
// Bridges the GPU internal memory protocol to the native
// LACOODA system bus.
//
// GPU side:
//
//     gpu_mem_req_s
//     gpu_mem_rsp_s
//
// System side:
//
//     bus_req_s
//     bus_rsp_s
//
// This module is a BUS MASTER.
//
// It is fundamentally different from gpu_register:
//
//     gpu_register
//         = bus slave
//         = CPU accesses GPU registers
//
//     gpu_bus_master
//         = bus master
//         = GPU accesses system memory
//
// Only one transaction may be outstanding at a time.
// ============================================================

module gpu_bus_master (
    input logic clk,
    input logic rst,

    // --------------------------------------------------------
    // GPU INTERNAL MEMORY INTERFACE
    // --------------------------------------------------------

    input  gpu_pkg::gpu_mem_req_s gpu_req,
    output gpu_pkg::gpu_mem_rsp_s gpu_rsp,

    // --------------------------------------------------------
    // LACOODA MASTER BUS
    // --------------------------------------------------------

    output bus_pkg::bus_req_s gpu_bus_req,
    input  bus_pkg::bus_rsp_s gpu_bus_rsp
);


    // ========================================================
    // TRANSACTION STATE
    // ========================================================

    typedef enum logic {

        GPU_MEM_IDLE,

        GPU_MEM_WAIT

    } gpu_mem_state_e;


    gpu_mem_state_e state;


    // ========================================================
    // REQUEST REGISTER
    // ========================================================
    //
    // Once a request begins, its contents must remain stable
    // until the bus completes the transaction.
    //
    // Therefore we latch the GPU request before driving the
    // system bus.
    // ========================================================

    gpu_pkg::gpu_mem_req_s request_reg;


    // ========================================================
    // STATE / REQUEST STORAGE
    // ========================================================

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            state       <= GPU_MEM_IDLE;
            request_reg <= '0;

        end else begin

            case (state)

                // ============================================
                // IDLE
                // ============================================

                GPU_MEM_IDLE: begin

                    if (gpu_req.valid) begin

                        request_reg <= gpu_req;

                        state <= GPU_MEM_WAIT;

                    end

                end


                // ============================================
                // WAIT FOR BUS
                // ============================================

                GPU_MEM_WAIT: begin

                    if (gpu_bus_rsp.ready) begin

                        request_reg <= '0;

                        state <= GPU_MEM_IDLE;

                    end

                end


                // ============================================
                // RECOVERY
                // ============================================

                default: begin

                    state       <= GPU_MEM_IDLE;
                    request_reg <= '0;

                end

            endcase

        end

    end


    // ========================================================
    // SYSTEM BUS REQUEST
    // ========================================================

    always_comb begin

        gpu_bus_req = '0;

        if (state == GPU_MEM_WAIT) begin

            gpu_bus_req.valid =
                1'b1;

            gpu_bus_req.op =
                request_reg.op;

            gpu_bus_req.addr =
                request_reg.addr;

            gpu_bus_req.wdata =
                request_reg.wdata;

        end

    end


    // ========================================================
    // GPU RESPONSE
    // ========================================================
    //
    // ready pulses when the system bus completes the current
    // transaction.
    // ========================================================

    always_comb begin

        gpu_rsp = '0;

        if (
            (state == GPU_MEM_WAIT) &&
            gpu_bus_rsp.ready
        ) begin

            gpu_rsp.ready =
                1'b1;

            gpu_rsp.rdata =
                gpu_bus_rsp.rdata;

        end

    end

endmodule