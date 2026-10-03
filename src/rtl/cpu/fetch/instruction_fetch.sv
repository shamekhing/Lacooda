`timescale 1ns/1ps

// ============================================================
// LACOODA instruction fetch unit
//
// The instruction memory is deliberately OUTSIDE the CPU. This unit owns
// the PC and a one-entry instruction buffer, and exposes a typed
// valid/ready I-BUS request/response interface to the surrounding SoC.
//
// Fetch protocol:
//   1. When run requests execution and nothing is buffered, the
//      instruction word at pc is fetched.
//   2. ibus_req stays stable until ibus_rsp.ready is asserted.
//   3. If the instruction uses an immediate (branch/jump, LOAD/STORE,
//      or ALU in immediate mode), ONE more word — the immediate — is
//      fetched from the word that follows the instruction.
//   4. The accepted instruction (and its immediate, if any) are buffered
//      inside the CPU.
//   5. The pc changes only when that buffered instruction retires, and
//      skips the immediate word as well.
//   6. A branch/jump retirement loads target instead of pc + word.
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
    input  cpu_pkg::word_t redirect_target,

    // I-BUS master request/response.
    output bus_pkg::bus_req_t ibus_req,
    input  bus_pkg::bus_rsp_t ibus_rsp,

    // Buffered instruction presented to the CPU core.
    output cpu_pkg::word_t pc,
    output cpu_pkg::instruction_t instruction,
    output cpu_pkg::word_t immediate_word,
    output logic instruction_available
);

    // Fetch state: idle, fetching the instruction, fetching its immediate.
    typedef enum logic [1:0] {
        FETCH_IDLE,
        FETCH_INSTR,
        FETCH_IMM
    } fetch_state_e;

    fetch_state_e fetch_state;
    logic has_imm;

    program_counter u_program_counter (
        .clk     (clk),
        .rst     (rst),
        .enable  (retire),
        .redirect(redirect),
        .target  (redirect_target),
        .has_imm (has_imm),
        .pc      (pc)
    );

    // The instruction word lives at pc; its immediate word (if any) is the
    // very next word in instruction memory.
    assign ibus_req.valid = (fetch_state != FETCH_IDLE);
    assign ibus_req.op    = bus_pkg::BUS_READ;
    assign ibus_req.addr  = (fetch_state == FETCH_IMM)
                            ? pc + cpu_pkg::word_t'(cpu_pkg::WORD_BYTES)
                            : pc;
    assign ibus_req.wdata = '0;

    // How many words the buffered instruction occupies. The pc uses this
    // when the instruction retires so the immediate word is never executed.
    assign has_imm = instruction_available &&
                     cpu_pkg::instr_uses_imm(instruction);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fetch_state           <= FETCH_IDLE;
            instruction_available <= 1'b0;
            instruction           <= '0;
            immediate_word        <= '0;
        end else begin
            // Retiring the current instruction frees the one-entry buffer.
            // If run remains asserted, immediately start the next fetch after
            // the same edge; the pc also advances on this retirement edge.
            if (retire) begin
                instruction_available <= 1'b0;
                if (run)
                    fetch_state <= FETCH_INSTR;
            end else if ((fetch_state == FETCH_IDLE) &&
                         !instruction_available && run) begin
                // Start the first request, or restart after a paused CPU.
                fetch_state <= FETCH_INSTR;
            end

            // A started instruction request remains active until the slave
            // accepts it. The accept decides whether an immediate follows:
            // with one, the instruction completes only after the immediate
            // word is buffered; without one, it is immediately available.
            if ((fetch_state == FETCH_INSTR) && ibus_rsp.ready) begin
                instruction           <= cpu_pkg::instruction_t'(ibus_rsp.rdata);
                fetch_state           <= cpu_pkg::instr_uses_imm(ibus_rsp.rdata)
                                         ? FETCH_IMM : FETCH_IDLE;
                instruction_available <= !cpu_pkg::instr_uses_imm(ibus_rsp.rdata);
            end else if ((fetch_state == FETCH_IMM) && ibus_rsp.ready) begin
                immediate_word        <= ibus_rsp.rdata;
                fetch_state           <= FETCH_IDLE;
                instruction_available <= 1'b1;
            end
        end
    end

endmodule
