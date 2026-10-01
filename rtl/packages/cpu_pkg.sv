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

    import opcode_pkg::*;

    // ============================================================
    // Independent parameter groups.
    //
    // There is no global CPU word width: the register file, the
    // instruction memory and the data memory each own their width, depth
    // and types. The CPU datapath word is the register word (reg_t).
    // ============================================================

    // ------------------------------------------------------------
    // Data memory group.
    // ------------------------------------------------------------
    localparam int DATA_MEMORY_WIDTH = 64;
    localparam int DATA_MEMORY_BYTES = DATA_MEMORY_WIDTH / 8;
    localparam int DATA_MEMORY_COUNT = 256;

    typedef logic [DATA_MEMORY_WIDTH-1:0] data_memory_t;

    // ------------------------------------------------------------
    // Register file group.
    //
    // This group also defines the CPU datapath word: ALU operands,
    // immediates, effective addresses and bus addresses are all reg_t.
    // ------------------------------------------------------------
    localparam int REG_FILE_WIDTH = 64;
    localparam int REG_FILE_BYTES = REG_FILE_WIDTH / 8;
    localparam int REG_FILE_COUNT = 64;
    localparam int REG_FILE_ADDR_WIDTH = $clog2(REG_FILE_COUNT);
    
    typedef logic [REG_FILE_WIDTH-1:0] reg_t;
    typedef logic [REG_FILE_ADDR_WIDTH-1:0] reg_addr_t;

    // R0 is architecturally hardwired to zero.
    localparam reg_addr_t ZERO_REG = '0;
    
    // ------------------------------------------------------------
    // Instruction memory group.
    // ------------------------------------------------------------
    localparam INSTRUCTION_MEMORY_INIT_FILE = "programs/program_0.hex";

    localparam int INSTRUCTION_MEMORY_WIDTH = 64;
    localparam int INSTRUCTION_MEMORY_BYTES = INSTRUCTION_MEMORY_WIDTH / 8;
    localparam int INSTRUCTION_MEMORY_COUNT = 256;

    typedef logic [INSTRUCTION_MEMORY_WIDTH-1:0] instruction_t;
    
    // Raw opcode field type. This intentionally covers both ALU opcodes
    // and non-ALU instruction opcodes such as branches and LOAD/STORE.
    // Every opcode constant comes from opcode_pkg, which is imported above.
    typedef logic [OPCODE_WIDTH-1:0] instruction_opcode_t;

    localparam int IMMEDIATE_WIDTH = 32;
    typedef logic [IMMEDIATE_WIDTH-1:0] imm_t;



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
    localparam int RS2_MSB = RS2_LSB + REG_FILE_ADDR_WIDTH - 1;
    localparam int RS1_LSB = RS2_MSB + 1;
    localparam int RS1_MSB = RS1_LSB + REG_FILE_ADDR_WIDTH - 1;
    localparam int RD_LSB = RS1_MSB + 1;
    localparam int RD_MSB = RD_LSB + REG_FILE_ADDR_WIDTH - 1;
    localparam int OPCODE_LSB = RD_MSB + 1;
    localparam int OPCODE_MSB = OPCODE_LSB + OPCODE_WIDTH - 1;
    localparam int I_BIT = OPCODE_MSB + 1;
    localparam int S_BIT = I_BIT + 1;
    localparam int RESERVED_LSB = S_BIT + 1;
    localparam int RESERVED_MSB = INSTRUCTION_MEMORY_WIDTH - 1;
    localparam int USED_INSTRUCTION_BITS = RESERVED_LSB;
    localparam int RESERVED_WIDTH = INSTRUCTION_MEMORY_WIDTH - USED_INSTRUCTION_BITS;

    // Run once at initialization, including standalone unit-test elaborations.
    function automatic bit validate_configuration();
        // Register-file group (also the CPU datapath word).
        if (REG_FILE_WIDTH < 64 || REG_FILE_WIDTH % 8 != 0)
            $fatal(1, "REG_FILE_WIDTH must be at least 64 and divisible by 8");
        if (IMMEDIATE_WIDTH <= 0 || IMMEDIATE_WIDTH % 8 != 0 ||
            IMMEDIATE_WIDTH > REG_FILE_WIDTH)
            $fatal(1, "IMMEDIATE_WIDTH must be positive, divisible by 8, and <= REG_FILE_WIDTH");
        if (REG_FILE_COUNT < 2)
            $fatal(1, "REG_FILE_COUNT must be at least 2 for a nonzero register-address width");

        // Instruction-memory group.
        if (INSTRUCTION_MEMORY_WIDTH <= 0 || INSTRUCTION_MEMORY_WIDTH % 8 != 0)
            $fatal(1, "INSTRUCTION_MEMORY_WIDTH must be positive and divisible by 8");
        if (INSTRUCTION_MEMORY_COUNT <= 0)
            $fatal(1, "INSTRUCTION_MEMORY_COUNT must be positive");

        // Data-memory group.
        if (DATA_MEMORY_WIDTH <= 0 || DATA_MEMORY_WIDTH % 8 != 0)
            $fatal(1, "DATA_MEMORY_WIDTH must be positive and divisible by 8");
        if (DATA_MEMORY_COUNT <= 0)
            $fatal(1, "DATA_MEMORY_COUNT must be positive");
        // The D-BUS carries the datapath word into and out of the data
        // memory, so the two words must match even though the groups are
        // declared independently.
        if (DATA_MEMORY_WIDTH != REG_FILE_WIDTH)
            $fatal(1, "DATA_MEMORY_WIDTH must equal REG_FILE_WIDTH (the datapath/D-BUS word)");

        // Instruction encoding.
        if (OPCODE_WIDTH < $clog2('h31))
            $fatal(1, "OPCODE_WIDTH cannot represent the existing Stage 7 opcodes");
        if (USED_INSTRUCTION_BITS > INSTRUCTION_MEMORY_WIDTH)
            $fatal(1, "Instruction fields exceed INSTRUCTION_MEMORY_WIDTH");
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

    // Sign-extend an immediate from IMMEDIATE_WIDTH to the datapath word.
    function automatic reg_t sign_extend_imm32(input imm_t value);
        return {{(REG_FILE_WIDTH-IMMEDIATE_WIDTH){value[IMMEDIATE_WIDTH-1]}}, value};
    endfunction

    // Zero-extend the IMMEDIATE_WIDTH-bit absolute branch/jump byte address.
    function automatic reg_t zero_extend_target(input imm_t value);
        return {{(REG_FILE_WIDTH-IMMEDIATE_WIDTH){1'b0}}, value};
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
