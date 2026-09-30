`timescale 1ns/1ps
`ifndef CPU_PKG_SV
`define CPU_PKG_SV

// ============================================================
// CPU package
//
// Single source of truth for the LACOODA CPU-wide constants,
// instruction layout, control-flow encodings, and instruction
// construction helpers.
//
// Stage 6 keeps the existing 64-bit instruction layout unchanged.
// ALU instructions use opcodes 0x00..0x27. Control-flow opcodes
// begin at 0x28, using the previously unused opcode space.
// ============================================================

package cpu_pkg;

    import alu_pkg::*;

    // ------------------------------------------------------------
    // Architectural widths and memory configuration.
    // ------------------------------------------------------------
    localparam int DATA_WIDTH = 64;
    localparam int REG_COUNT = 64;
    localparam int INSTRUCTION_WIDTH = 64;
    localparam int INSTRUCTION_BYTES = INSTRUCTION_WIDTH / 8;
    localparam int IMMEDIATE_WIDTH = 32;
    localparam int REG_ADDR_WIDTH = $clog2(REG_COUNT);
    localparam int INSTRUCTION_MEMORY_DEPTH = 256;
    localparam INSTRUCTION_MEMORY_INIT_FILE = "programs/program_0.hex";

    typedef logic [DATA_WIDTH-1:0] data_t;
    typedef logic [REG_ADDR_WIDTH-1:0] reg_addr_t;
    typedef logic [INSTRUCTION_WIDTH-1:0] instruction_t;
    typedef logic [IMMEDIATE_WIDTH-1:0] imm_t;

    localparam reg_addr_t ZERO_REG = '0;

    // ------------------------------------------------------------
    // Stage 6 control-flow opcodes.
    //
    // The instruction opcode field is still 6 bits wide. These
    // values occupy unused encodings immediately after ALU_GES.
    // ------------------------------------------------------------
    localparam opcode_t CTRL_JMP  = opcode_t'(6'h28);
    localparam opcode_t CTRL_BEQ  = opcode_t'(6'h29);
    localparam opcode_t CTRL_BNE  = opcode_t'(6'h2A);
    localparam opcode_t CTRL_BLT  = opcode_t'(6'h2B);
    localparam opcode_t CTRL_BGE  = opcode_t'(6'h2C);
    localparam opcode_t CTRL_BLTU = opcode_t'(6'h2D);
    localparam opcode_t CTRL_BGEU = opcode_t'(6'h2E);

    // Internal branch-unit condition encoding. This is a control
    // signal between decoder and branch_unit; it is NOT another
    // field in the 64-bit instruction word.
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
    localparam int RESERVED_WIDTH = INSTRUCTION_WIDTH - RESERVED_LSB;

    // Packed overlay of the 64-bit instruction word. The first
    // member occupies the most significant bits.
    typedef struct packed {
        logic [RESERVED_WIDTH-1:0] reserved;
        logic update_status;
        logic immediate_mode;
        opcode_t opcode;
        reg_addr_t rd;
        reg_addr_t rs1;
        reg_addr_t rs2;
        imm_t imm32;
    } instruction_fields_t;

    // Sign-extend a normal ALU immediate from 32 to DATA_WIDTH.
    function automatic data_t sign_extend_imm32(input imm_t value);
        return {{(DATA_WIDTH-IMMEDIATE_WIDTH){value[IMMEDIATE_WIDTH-1]}}, value};
    endfunction

    // Zero-extend a Stage-6 absolute branch target. Stage 6 uses
    // IMM32 as a byte address in the low 4 GiB of the address space.
    function automatic data_t zero_extend_target(input imm_t value);
        return {{(DATA_WIDTH-IMMEDIATE_WIDTH){1'b0}}, value};
    endfunction

    // Assemble a normal ALU instruction from its fields.
    function automatic instruction_t encode_instruction(
        input opcode_t opcode,
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
        return fields;
    endfunction

    // Assemble a conditional branch.
    //
    //   opcode : CTRL_BEQ/BNE/BLT/BGE/BLTU/BGEU
    //   rs1    : first comparison register
    //   rs2    : second comparison register
    //   imm32  : absolute byte address of branch target
    //
    // RD, I, S and reserved bits are deliberately zero.
    function automatic instruction_t encode_branch(
        input opcode_t opcode,
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
        return fields;
    endfunction

    // Assemble an unconditional jump. JMP consumes no registers;
    // only the absolute target address is encoded.
    function automatic instruction_t encode_jump(input imm_t target);
        return encode_branch(CTRL_JMP, ZERO_REG, ZERO_REG, target);
    endfunction

endpackage
`endif
