`timescale 1ns/1ps

// ============================================================
// LACOODA INSTRUCTION FETCH
// ============================================================
//
// Owns the program counter and instruction buffer.
//
// Fetch sequence:
//
//   1. Request instruction at PC.
//   2. Wait for I-BUS completion.
//   3. Fetch immediate word when required.
//   4. Buffer the complete instruction.
//   5. Wait for retirement.
//   6. Continue fetching.
//
// Once started, a fetch is not cancelled when run falls.
//
// The instruction bus is read-only.
//
// Stage 1:
//   - Explicitly drive the new write-strobe field.
//   - Preserve the original fetch state machine.
//
// The existing CPU does not implement instruction-fetch
// exceptions. Error responses therefore need an explicit
// fault-handling policy before full integration is complete.
// ============================================================

module instruction_fetch (

    input logic clk,
    input logic rst,
    input logic run,

    input logic retire,
    input logic redirect,
    input cpu_pkg::word_t redirect_target,

    output bus_pkg::bus_req_s cpu_instr_bus_req,
    input  bus_pkg::bus_rsp_s cpu_instr_bus_rsp,

    output cpu_pkg::instruction_t instruction,
    output cpu_pkg::word_t immediate_word,
    output logic instruction_available

);

    // ========================================================
    // FETCH STATES
    // ========================================================

    typedef enum logic [1:0] {

        FETCH_IDLE,
        FETCH_INSTR,
        FETCH_IMM

    } fetch_state_e;

    fetch_state_e fetch_state;

    // ========================================================
    // PROGRAM COUNTER
    // ========================================================

    logic has_imm;
    cpu_pkg::word_t pc;

    program_counter u_program_counter (

        .clk      (clk),
        .rst      (rst),

        .enable   (retire),

        .redirect (redirect),
        .target   (redirect_target),

        .has_imm  (has_imm),
        .pc       (pc)

    );

    // ========================================================
    // INSTRUCTION BUS REQUEST
    // ========================================================
    //
    // Fetch instruction at PC.
    //
    // Fetch immediate at PC + WORD_BYTES.
    //
    // No instruction-bus writes are permitted.
    //
    // Write data and strobes are always zero.
    // ========================================================

    assign cpu_instr_bus_req.valid =
        fetch_state != FETCH_IDLE;

    assign cpu_instr_bus_req.op =
        bus_pkg::BUS_READ;

    assign cpu_instr_bus_req.addr =
        (fetch_state == FETCH_IMM)
            ? pc + cpu_pkg::word_t'(cpu_pkg::WORD_BYTES)
            : pc;

    assign cpu_instr_bus_req.wdata = '0;

    assign cpu_instr_bus_req.wstrb =
        bus_pkg::BUS_STRB_NONE;

    // ========================================================
    // IMMEDIATE-WORD CLASSIFICATION
    // ========================================================

    assign has_imm =
        instruction_available &&
        cpu_pkg::instr_uses_imm(instruction);

    // ========================================================
    // FETCH STATE MACHINE
    // ========================================================

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            fetch_state           <= FETCH_IDLE;
            instruction_available <= 1'b0;

            instruction           <= '0;
            immediate_word        <= '0;

        end else if (retire) begin

            // ------------------------------------------------
            // Retire the buffered instruction.
            //
            // Begin another fetch only when run is asserted.
            // ------------------------------------------------

            fetch_state <=
                run ? FETCH_INSTR : FETCH_IDLE;

            instruction_available <= 1'b0;

            instruction    <= '0;
            immediate_word <= '0;

        end else begin

            case (fetch_state)

                // ============================================
                // IDLE
                // ============================================

                FETCH_IDLE: begin

                    if (
                        run &&
                        !instruction_available
                    ) begin

                        fetch_state <= FETCH_INSTR;

                    end

                end

                // ============================================
                // FETCH INSTRUCTION
                // ============================================

                FETCH_INSTR: begin

                    if (cpu_instr_bus_rsp.ready) begin

                        instruction <=
                            cpu_pkg::instruction_t'(
                                cpu_instr_bus_rsp.rdata
                            );

                        if (
                            cpu_pkg::instr_uses_imm(
                                cpu_instr_bus_rsp.rdata
                            )
                        ) begin

                            fetch_state <= FETCH_IMM;

                            instruction_available <= 1'b0;

                        end else begin

                            fetch_state <= FETCH_IDLE;

                            instruction_available <= 1'b1;

                        end

                    end

                end

                // ============================================
                // FETCH IMMEDIATE
                // ============================================

                FETCH_IMM: begin

                    if (cpu_instr_bus_rsp.ready) begin

                        immediate_word <= cpu_instr_bus_rsp.rdata;

                        fetch_state <= FETCH_IDLE;

                        instruction_available <= 1'b1;

                    end

                end

                // ============================================
                // INVALID STATE RECOVERY
                // ============================================

                default: begin

                    fetch_state <= FETCH_IDLE;

                    instruction_available <= 1'b0;

                end

            endcase

        end

    end

endmodule