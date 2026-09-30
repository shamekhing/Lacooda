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
// Stage 7 keeps the existing instruction layout unchanged.
// ALU instructions use opcodes 0x00..0x27, Stage-6 control-flow uses
// 0x28..0x2E, and Stage-7 memory operations use 0x2F..0x30.
// ============================================================

package cpu_pkg;

    import alu_pkg::*;

    // ------------------------------------------------------------
    // Architectural widths and memory configuration.
    // ------------------------------------------------------------
    localparam int DATA_WIDTH = 64;
    localparam int DATA_BYTES = DATA_WIDTH / 8;
    localparam int REG_COUNT = 64;
    localparam int INSTRUCTION_WIDTH = 64;
    localparam int INSTRUCTION_BYTES = INSTRUCTION_WIDTH / 8;
    localparam int IMMEDIATE_WIDTH = 32;
    localparam int REG_ADDR_WIDTH = $clog2(REG_COUNT);
    localparam int INSTRUCTION_MEMORY_DEPTH = 256;
    localparam int DATA_MEMORY_DEPTH = 256;
    localparam INSTRUCTION_MEMORY_INIT_FILE = "programs/program_0.hex";

    typedef logic [DATA_WIDTH-1:0] data_t;
    typedef logic [REG_ADDR_WIDTH-1:0] reg_addr_t;
    typedef logic [INSTRUCTION_WIDTH-1:0] instruction_t;
    typedef logic [IMMEDIATE_WIDTH-1:0] imm_t;

    // Raw opcode field type. This intentionally covers both ALU opcodes
    // and non-ALU instruction opcodes such as branches and LOAD/STORE.
    typedef logic [OPCODE_WIDTH-1:0] instruction_opcode_t;

    localparam reg_addr_t ZERO_REG = '0;

    // ------------------------------------------------------------
    // Stage 6 control-flow opcodes.
    // ------------------------------------------------------------
    localparam instruction_opcode_t CTRL_JMP  = instruction_opcode_t'('h28);
    localparam instruction_opcode_t CTRL_BEQ  = instruction_opcode_t'('h29);
    localparam instruction_opcode_t CTRL_BNE  = instruction_opcode_t'('h2A);
    localparam instruction_opcode_t CTRL_BLT  = instruction_opcode_t'('h2B);
    localparam instruction_opcode_t CTRL_BGE  = instruction_opcode_t'('h2C);
    localparam instruction_opcode_t CTRL_BLTU = instruction_opcode_t'('h2D);
    localparam instruction_opcode_t CTRL_BGEU = instruction_opcode_t'('h2E);

    // ------------------------------------------------------------
    // Stage 7 memory opcodes.
    //
    // Both instructions use a signed IMMEDIATE_WIDTH byte offset:
    //
    //   LOAD  rd, [rs1 + imm]
    //   STORE rs2, [rs1 + imm]
    //
    // The I and S instruction bits remain zero. LOAD/STORE have their
    // own fixed format, so they do not need the normal ALU I-bit mode.
    // ------------------------------------------------------------
    localparam instruction_opcode_t MEM_LOAD  = instruction_opcode_t'('h2F);
    localparam instruction_opcode_t MEM_STORE = instruction_opcode_t'('h30);

    // Internal branch-unit condition encoding. This is a control
    // signal between decoder and branch_unit; it is NOT another
    // field in the instruction word.
    typedef enum logic [2:0] {
        BR_ALWAYS,
        BR_EQ,
        BR_NE,
        BR_LT,
        BR_GE,
        BR_LTU,
        BR_GEU
    } branch_condition_t;

    // ------------------------------------------------------------
    // Bit positions of the packed instruction fields (LSB first).
    // ------------------------------------------------------------
    localparam int IMM_LSB = 0;
    localparam int IMM_MSB = IMM_LSB + IMMEDIATE_WIDTH - 1;
    localparam int RS2_LSB = IMM_MSB + 1;
    localparam int RS2_MSB = RS2_LSB + REG_ADDR_WIDTH - 1;
    localparam int RS1_LSB = RS2_MSB + 1;
    localparam int RS1_MSB = RS1_LSB + REG_ADDR_WIDTH - 1;
    localparam int RD_LSB = RS1_MSB + 1;
    localparam int RD_MSB = RD_LSB + REG_ADDR_WIDTH - 1;
    localparam int OPCODE_LSB = RD_MSB + 1;
    localparam int OPCODE_MSB = OPCODE_LSB + OPCODE_WIDTH - 1;
    localparam int I_BIT = OPCODE_MSB + 1;
    localparam int S_BIT = I_BIT + 1;
    localparam int RESERVED_LSB = S_BIT + 1;
    localparam int RESERVED_MSB = INSTRUCTION_WIDTH - 1;
    localparam int USED_INSTRUCTION_BITS = RESERVED_LSB;
    localparam int RESERVED_WIDTH = INSTRUCTION_WIDTH - USED_INSTRUCTION_BITS;

    // Run once at initialization, including standalone unit-test elaborations.
    function automatic bit validate_configuration();
        if (DATA_WIDTH < 64 || DATA_WIDTH % 8 != 0)
            $fatal(1, "DATA_WIDTH must be at least 64 and divisible by 8");
        if (INSTRUCTION_WIDTH <= 0 || INSTRUCTION_WIDTH % 8 != 0)
            $fatal(1, "INSTRUCTION_WIDTH must be positive and divisible by 8");
        if (IMMEDIATE_WIDTH <= 0 || IMMEDIATE_WIDTH % 8 != 0 ||
            IMMEDIATE_WIDTH > DATA_WIDTH)
            $fatal(1, "IMMEDIATE_WIDTH must be positive, divisible by 8, and <= DATA_WIDTH");
        if (REG_COUNT < 2)
            $fatal(1, "REG_COUNT must be at least 2 for a nonzero register-address width");
        if (OPCODE_WIDTH < $clog2('h31))
            $fatal(1, "OPCODE_WIDTH cannot represent the existing Stage 7 opcodes");
        if (USED_INSTRUCTION_BITS > INSTRUCTION_WIDTH)
            $fatal(1, "Instruction fields exceed INSTRUCTION_WIDTH");
        if (INSTRUCTION_MEMORY_DEPTH <= 0)
            $fatal(1, "INSTRUCTION_MEMORY_DEPTH must be positive");
        if (DATA_MEMORY_DEPTH <= 0)
            $fatal(1, "DATA_MEMORY_DEPTH must be positive");
        return 1'b1;
    endfunction

    bit configuration_valid = validate_configuration();

    // Packed payload occupies the low USED_INSTRUCTION_BITS of the instruction.
    // Reserved bits stay outside the struct so RESERVED_WIDTH may legally be zero.
    typedef struct packed {
        logic update_status;
        logic immediate_mode;
        instruction_opcode_t opcode;
        reg_addr_t rd;
        reg_addr_t rs1;
        reg_addr_t rs2;
        imm_t imm32;
    } instruction_fields_t;

    // Sign-extend an immediate from IMMEDIATE_WIDTH to DATA_WIDTH.
    function automatic data_t sign_extend_imm32(input imm_t value);
        return {{(DATA_WIDTH-IMMEDIATE_WIDTH){value[IMMEDIATE_WIDTH-1]}}, value};
    endfunction

    // Zero-extend the IMMEDIATE_WIDTH-bit absolute branch/jump byte address.
    function automatic data_t zero_extend_target(input imm_t value);
        return {{(DATA_WIDTH-IMMEDIATE_WIDTH){1'b0}}, value};
    endfunction

    // Assemble a normal ALU instruction from its fields.
    function automatic instruction_t encode_instruction(
        input instruction_opcode_t opcode,
        input reg_addr_t rd, rs1, rs2,
        input logic immediate_mode, update_status,
        input imm_t imm32
    );
        instruction_fields_t fields;
        fields = '0;
        fields.opcode = opcode;
        fields.rd = rd;
        fields.rs1 = rs1;
        fields.rs2 = rs2;
        fields.immediate_mode = immediate_mode;
        fields.update_status = update_status;
        fields.imm32 = imm32;
        return instruction_t'(fields);
    endfunction

    // Assemble a conditional branch.
    // IMM32 is an absolute byte address.
    function automatic instruction_t encode_branch(
        input instruction_opcode_t opcode,
        input reg_addr_t rs1,
        input reg_addr_t rs2,
        input imm_t target
    );
        instruction_fields_t fields;
        fields = '0;
        fields.opcode = opcode;
        fields.rs1 = rs1;
        fields.rs2 = rs2;
        fields.imm32 = target;
        return instruction_t'(fields);
    endfunction

    // Assemble an unconditional jump.
    function automatic instruction_t encode_jump(input imm_t target);
        return encode_branch(CTRL_JMP, ZERO_REG, ZERO_REG, target);
    endfunction

    // Assemble LOAD rd, [base + offset].
    function automatic instruction_t encode_load(
        input reg_addr_t rd,
        input reg_addr_t base,
        input imm_t offset
    );
        instruction_fields_t fields;
        fields = '0;
        fields.opcode = MEM_LOAD;
        fields.rd = rd;
        fields.rs1 = base;
        fields.imm32 = offset;
        return instruction_t'(fields);
    endfunction

    // Assemble STORE source, [base + offset].
    function automatic instruction_t encode_store(
        input reg_addr_t source,
        input reg_addr_t base,
        input imm_t offset
    );
        instruction_fields_t fields;
        fields = '0;
        fields.opcode = MEM_STORE;
        fields.rs1 = base;
        fields.rs2 = source;
        fields.imm32 = offset;
        return instruction_t'(fields);
    endfunction

endpackage
`endif
