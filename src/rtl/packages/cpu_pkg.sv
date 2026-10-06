`timescale 1ns/1ps
`ifndef CPU_PKG_SV
`define CPU_PKG_SV

// ============================================================
// CPU package
//
// Single source of truth for the LACOODA CPU-wide constants,
// instruction layout, control-flow/memory encodings, and instruction
// construction helpers.
//
// There is exactly ONE architectural word: WORD_WIDTH (32 or 64 bits).
// Registers, ALU operands, immediates, addresses, status, bus payloads,
// data-memory words and instruction words are all that word. Nothing in
// this package or the RTL may declare its own architectural width.
//
// Instruction encoding (LSB first):
//   RS2, RS1, RD, OPCODE, I (immediate mode), S (update status).
// The immediate is NOT an instruction field. An instruction that needs
// an immediate is followed by one full word in instruction memory; the
// fetch unit reads it and the PC skips it on retirement.
// ============================================================

package cpu_pkg;

    import opcode_pkg::*;

    // ------------------------------------------------------------
    // THE global word.
    //
    // Selection: define LACOODA_WORD_WIDTH at compile time, e.g.
    //   iverilog -DLACOODA_WORD_WIDTH=32 ...
    // ------------------------------------------------------------

    `ifndef LACOODA_WORD_WIDTH
        `define LACOODA_WORD_WIDTH 32
    `endif

    localparam int WORD_WIDTH = `LACOODA_WORD_WIDTH;
    localparam int WORD_BYTES = WORD_WIDTH / 8;

    // ------------------------------------------------------------
    // Architectural types
    // ------------------------------------------------------------

    // THE architectural word. Every architectural payload below is this
    // word; there is no second width anywhere in the design.
    typedef logic [WORD_WIDTH-1:0] word_t;

    // The instruction stream is also exactly one word.
    typedef word_t instruction_t;

    // ------------------------------------------------------------
    // Register file group.
    // ------------------------------------------------------------

    localparam int REG_FILE_COUNT = 64;
    localparam int REG_FILE_ADDR_WIDTH = $clog2(REG_FILE_COUNT);

    typedef logic [REG_FILE_ADDR_WIDTH-1:0] reg_addr_t;

    // R0 is architecturally hardwired to zero.
    localparam reg_addr_t ZERO_REG = '0;

    // ------------------------------------------------------------
    // Memory depth groups (width is the global word; only depth lives here).
    // ------------------------------------------------------------

    localparam int INSTRUCTION_MEMORY_COUNT = 256;
    localparam int DATA_MEMORY_COUNT = 256;
    // Program image. Word-size-dependent (branch targets are byte
    // addresses), so each global word has its own image.
    // Path is resolved by the tool flow relative to the repository root
    // (iverilog regressions and GowinSynthesis both run from there), so the
    // "src/" prefix matches where the images actually live.
    localparam PROGRAM_FILE =
        (WORD_WIDTH == 32) ? "src/programs/genesis_32.hex" : "src/programs/genesis_64.hex";

    // ------------------------------------------------------------
    // Architectural STATUS: a dedicated 32-bit register, independent
    // of the global CPU word. Only [4:0] have implemented state:
    //   [4] DZ, [3] V, [2] C, [1] N, [0] Z
    // [31:5] are reserved and always read as zero.
    // ------------------------------------------------------------

    localparam int STATUS_WIDTH = 32;

    typedef logic [STATUS_WIDTH-1:0] status_t;

    // ALU condition flags, packed MSB-first:
    //   Z  : result is zero
    //   N  : result sign bit (MSB)
    //   C  : carry out / no borrow
    //   V  : signed overflow
    //   DZ : divide by zero
    typedef struct packed {
        logic Z;
        logic N;
        logic C;
        logic V;
        logic DZ;
    } flags_s;

    function automatic flags_s make_flags(
        input logic z, n, c, v, dz
    );
        flags_s f;
        f.Z  = z;
        f.N  = n;
        f.C  = c;
        f.V  = v;
        f.DZ = dz;
        return f;
    endfunction

    // ------------------------------------------------------------
    // Bit positions of the packed instruction instr_fields (LSB first).
    // There is no immediate field: the immediate is the word that
    // follows an instruction that uses one.
    // ------------------------------------------------------------

    localparam int RS2_LSB = 0;
    localparam int RS2_MSB = RS2_LSB + REG_FILE_ADDR_WIDTH - 1;
    localparam int RS1_LSB = RS2_MSB + 1;
    localparam int RS1_MSB = RS1_LSB + REG_FILE_ADDR_WIDTH - 1;
    localparam int RD_LSB = RS1_MSB + 1;
    localparam int RD_MSB = RD_LSB + REG_FILE_ADDR_WIDTH - 1;
    localparam int OPCODE_LSB = RD_MSB + 1;
    localparam int OPCODE_MSB = OPCODE_LSB + OPCODE_WIDTH - 1;
    localparam int IMM_MODE_BIT = OPCODE_MSB + 1;
    localparam int UPDATE_STATUS_BIT = IMM_MODE_BIT + 1;
    localparam int RESERVED_LSB = UPDATE_STATUS_BIT + 1;
    localparam int RESERVED_MSB = WORD_WIDTH - 1;
    localparam int USED_INSTRUCTION_BITS = RESERVED_LSB;
    localparam int RESERVED_WIDTH = WORD_WIDTH - USED_INSTRUCTION_BITS;

    // Run once at initialization, including standalone unit-test elaborations.
    function automatic bit validate_configuration();
        // Global word: the single root of every architectural width.
        if (WORD_WIDTH != 32 && WORD_WIDTH != 64)
            $fatal(1, "WORD_WIDTH must be 32 or 64");
        if (WORD_WIDTH % 8 != 0)
            $fatal(1, "WORD_WIDTH must be divisible by 8");

        // Depths.
        if (REG_FILE_COUNT < 2)
            $fatal(1, "REG_FILE_COUNT must be at least 2 for a nonzero register-address width");
        if (INSTRUCTION_MEMORY_COUNT <= 0)
            $fatal(1, "INSTRUCTION_MEMORY_COUNT must be positive");
        if (DATA_MEMORY_COUNT <= 0)
            $fatal(1, "DATA_MEMORY_COUNT must be positive");

        // Instruction encoding must fit inside one global word.
        if (OPCODE_WIDTH < $clog2('h31))
            $fatal(1, "OPCODE_WIDTH cannot represent the existing Stage 7 opcodes");
        if (USED_INSTRUCTION_BITS > WORD_WIDTH)
            $fatal(1, "Instruction instr_fields exceed the global word");
        return 1'b1;
    endfunction

    // Packed payload occupies the low USED_INSTRUCTION_BITS of the instruction.
    // Reserved bits stay outside the struct so RESERVED_WIDTH may legally be zero.
    typedef struct packed {
        logic update_status;
        logic immediate_mode;
        opcode_t opcode;
        reg_addr_t rd;
        reg_addr_t rs1;
        reg_addr_t rs2;
    } instruction_s;

    // ------------------------------------------------------------
    // Immediate presence.
    //
    // An instruction is followed by an immediate word when it is a
    // branch/jump, a LOAD/STORE, or an ALU op in immediate mode.
    // The predicate is a pure function of the instruction word so the
    // fetch unit, the PC skip and the cpu_decoder can never disagree.
    // ------------------------------------------------------------

    function automatic logic uses_imm(
        input opcode_t opcode,
        input logic immediate_mode
    );
        return is_branch_opcode(opcode) || is_memory_opcode(opcode) || immediate_mode;
    endfunction

    function automatic logic instr_uses_imm(input instruction_t instruction);
        instruction_s instr_fields;
        instr_fields = instruction;
        return uses_imm(instr_fields.opcode, instr_fields.immediate_mode);
    endfunction

    // Assemble a normal ALU instruction from its instr_fields.
    // The immediate value, if any, is written into the word that follows.
    function automatic instruction_t encode_instruction(
        input opcode_t opcode,
        input reg_addr_t rd, rs1, rs2,
        input logic immediate_mode, update_status
    );
        instruction_s instr_fields;
        instr_fields = '0;
        instr_fields.opcode = opcode;
        instr_fields.rd = rd;
        instr_fields.rs1 = rs1;
        instr_fields.rs2 = rs2;
        instr_fields.immediate_mode = immediate_mode;
        instr_fields.update_status = update_status;
        return instruction_t'(instr_fields);
    endfunction

    // Assemble a conditional branch. The absolute byte-address target
    // is written into the word that follows.
    function automatic instruction_t encode_branch(
        input opcode_t opcode,
        input reg_addr_t rs1,
        input reg_addr_t rs2
    );
        instruction_s instr_fields;
        instr_fields = '0;
        instr_fields.opcode = opcode;
        instr_fields.rs1 = rs1;
        instr_fields.rs2 = rs2;
        return instruction_t'(instr_fields);
    endfunction

    // Assemble an unconditional jump.
    function automatic instruction_t encode_jump();
        return encode_branch(CTRL_JMP, ZERO_REG, ZERO_REG);
    endfunction

    // Assemble LOAD rd, [base + offset]. The signed byte offset is
    // written into the word that follows.
    function automatic instruction_t encode_load(
        input reg_addr_t rd,
        input reg_addr_t base
    );
        instruction_s instr_fields;
        instr_fields = '0;
        instr_fields.opcode = MEM_LOAD;
        instr_fields.rd = rd;
        instr_fields.rs1 = base;
        return instruction_t'(instr_fields);
    endfunction

    // Assemble STORE source, [base + offset]. The signed byte offset is
    // written into the word that follows.
    function automatic instruction_t encode_store(
        input reg_addr_t source,
        input reg_addr_t base
    );
        instruction_s instr_fields;
        instr_fields = '0;
        instr_fields.opcode = MEM_STORE;
        instr_fields.rs1 = base;
        instr_fields.rs2 = source;
        return instruction_t'(instr_fields);
    endfunction

endpackage
`endif
