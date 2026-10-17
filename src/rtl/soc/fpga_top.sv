`timescale 1ns/1ps

// ============================================================
// LACOODA FPGA TOP — STAGE 4
// ============================================================
//
// TARGET
//
//   Sipeed Tang Primer 20K
//
// BOARD INTERFACE
//
//   clk27  : 27 MHz system clock
//   btn_n0 : Active-low reset button
//   btn_n1 : Active-low run button
//   led0   : CPU instruction retirement
//   led1   : Illegal instruction
//   led2-5 : Reserved
//
// STAGE 4
//
//   The system includes a three-master arbiter.
//
//   CPU:
//     Connected and active.
//
//   GPU:
//     Memory master currently disabled.
//
//   TPU:
//     Memory master currently disabled.
//
//   DDR3:
//     Backend unavailable until physical controller
//     integration is completed.
//
// This wrapper preserves the existing physical port list
// and does not invent FPGA pin assignments.
// ============================================================

module fpga_top (

    input logic clk27,

    input logic btn_n0,
    input logic btn_n1,

    output logic led0,
    output logic led1,
    output logic led2,
    output logic led3,
    output logic led4,
    output logic led5

);

    // ========================================================
    // BUTTON SYNCHRONIZERS
    // ========================================================
    //
    // Two-stage synchronization of asynchronous button
    // signals into the 27 MHz clock domain.
    //
    // Internal rst/run signals are active-high.
    // ========================================================

    logic [1:0] rst_sync = 2'b11;
    logic [1:0] run_sync = 2'b00;

    logic rst;
    logic run;

    always_ff @(posedge clk27) begin

        rst_sync <= {
            rst_sync[0],
            ~btn_n0
        };

        run_sync <= {
            run_sync[0],
            ~btn_n1
        };

    end

    assign rst = rst_sync[1];
    assign run = run_sync[1];

    // ========================================================
    // CPU STATUS
    // ========================================================

    logic retire_valid;
    logic illegal_instr;

    // ========================================================
    // GPU MEMORY MASTER
    // ========================================================
    //
    // The existing GPU only contains MMIO registers.
    //
    // It cannot yet generate framebuffer memory requests.
    //
    // Therefore, its master request remains inactive.
    // ========================================================

    bus_pkg::bus_req_s gpu_bus_req;
    bus_pkg::bus_rsp_s gpu_bus_rsp;

    assign gpu_bus_req = '0;

    // ========================================================
    // TPU MEMORY MASTER
    // ========================================================
    //
    // No TPU execution engine has been connected yet.
    //
    // Reserve its native bus connection without generating
    // invalid transactions.
    // ========================================================

    bus_pkg::bus_req_s tpu_bus_req;
    bus_pkg::bus_rsp_s tpu_bus_rsp;

    assign tpu_bus_req = '0;

    // ========================================================
    // DDR3 BACKEND
    // ========================================================
    //
    // The native bus bridge exists.
    //
    // The physical Gowin DDR3 controller is not connected
    // in this configuration.
    //
    // Report the backend as unavailable.
    //
    // The DDR3 bridge responds with a bus error instead
    // of issuing transactions into nonexistent hardware.
    // ========================================================

    logic ddr3_backend_ready;

    bus_pkg::bus_req_s ddr3_backend_bus_req;
    bus_pkg::bus_rsp_s ddr3_backend_bus_rsp;

    assign ddr3_backend_ready = 1'b0;
    assign ddr3_backend_bus_rsp   = '0;

    // ========================================================
    // LACOODA SYSTEM
    // ========================================================

    system u_system (

        .clk                (clk27),
        .rst                (rst),
        .run                (run),

        .retire_valid       (retire_valid),
        .illegal_instr      (illegal_instr),

        .gpu_bus_req        (gpu_bus_req),
        .gpu_bus_rsp        (gpu_bus_rsp),

        .tpu_bus_req        (tpu_bus_req),
        .tpu_bus_rsp        (tpu_bus_rsp),

        .ddr3_backend_ready (ddr3_backend_ready),

        .ddr3_backend_bus_req   (ddr3_backend_bus_req),
        .ddr3_backend_bus_rsp   (ddr3_backend_bus_rsp)

    );

    // ========================================================
    // BOARD STATUS OUTPUTS
    // ========================================================

    assign led0 = retire_valid;
    assign led1 = illegal_instr;

    assign led2 = 1'b0;
    assign led3 = 1'b0;
    assign led4 = 1'b0;
    assign led5 = 1'b0;

endmodule