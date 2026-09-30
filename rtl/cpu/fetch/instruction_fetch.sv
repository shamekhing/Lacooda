`timescale 1ns/1ps

// ============================================================
// LACOODA instruction fetch unit
//
// The instruction memory is deliberately OUTSIDE the CPU. This unit owns
// the PC and a one-entry instruction buffer, and exposes an instruction
// valid/ready master interface to the surrounding SoC.
//
// Fetch protocol:
//   1. When run requests execution and no instruction is buffered, a fetch
//      request is started.
//   2. ibus_valid/address remain stable until ibus_ready is asserted.
//   3. The accepted instruction is buffered inside the CPU.
//   4. The PC changes only when that buffered instruction retires.
//   5. A branch/jump retirement loads target instead of PC+instruction size.
//
// Once a fetch request has started, deasserting run does not abandon it.
// Once an instruction has been fetched, it is allowed to retire atomically;
// run controls whether the CPU starts fetching the NEXT instruction.
// ============================================================

module instruction_fetch (
    input  logic clk,
    input  logic rst,
    input  logic run,

    // Current buffered instruction retirement from the CPU core.
    input  logic retire,
    input  logic redirect,
    input  cpu_pkg::data_t redirect_target,

    // Instruction-bus master request/response.
    output logic                  ibus_valid,
    output cpu_pkg::data_t        ibus_address,
    input  logic                  ibus_ready,
    input  cpu_pkg::instruction_t ibus_read_data,

    // Buffered instruction presented to the CPU core.
    output cpu_pkg::data_t        pc,
    output cpu_pkg::instruction_t instruction,
    output logic                  instruction_available
);

    logic fetch_request_active;

    program_counter u_program_counter (
        .clk      (clk),
        .rst      (rst),
        .enable   (retire),
        .redirect (redirect),
        .target   (redirect_target),
        .pc       (pc)
    );

    assign ibus_valid = fetch_request_active;
    assign ibus_address = pc;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fetch_request_active <= 1'b0;
            instruction_available <= 1'b0;
            instruction <= '0;
        end else begin
            // Retiring the current instruction frees the one-entry buffer.
            // If run remains asserted, immediately start the next fetch after
            // the same edge; the PC also advances on this retirement edge.
            if (retire) begin
                instruction_available <= 1'b0;
                if (run)
                    fetch_request_active <= 1'b1;
            end else if (!instruction_available && !fetch_request_active && run) begin
                // Start the first request, or restart after a paused CPU.
                fetch_request_active <= 1'b1;
            end

            // A started request remains active until the slave accepts it.
            if (fetch_request_active && ibus_ready) begin
                instruction <= ibus_read_data;
                instruction_available <= 1'b1;
                fetch_request_active <= 1'b0;
            end
        end
    end

endmodule
