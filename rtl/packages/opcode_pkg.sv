`timescale 1ns/1ps
`ifndef OPCODE_PKG_SV
`define OPCODE_PKG_SV

// ============================================================
// Opcode package
//
// Single source of truth for the opcode field width, the complete opcode
// map and the opcode classification helpers.
//
// Opcode map:
//   ALU operations   0x00..0x27
//   control flow     0x28..0x2E
//   memory           0x2F..0x30
//
// This package depends on no other package, so every other package or
// module can import it without creating a circular package dependency.
// The classification helpers take the raw opcode-field bits rather than
// an enum type for the same reason, and keep call sites cast-free.
// ============================================================

package opcode_pkg;

    localparam int OPCODE_WIDTH = 6;

    typedef enum logic [OPCODE_WIDTH-1:0] {
        ALU_ADD    = 'h00,
        ALU_ADC    = 'h01,
        ALU_SUB    = 'h02,
        ALU_SBC    = 'h03,
        ALU_MUL    = 'h04,
        ALU_MULH   = 'h05,
        ALU_DIVU   = 'h06,
        ALU_MODU   = 'h07,
        ALU_DIVS   = 'h08,
        ALU_MODS   = 'h09,
        ALU_NEG    = 'h0A,
        ALU_ABS    = 'h0B,
        ALU_MINU   = 'h0C,
        ALU_MAXU   = 'h0D,
        ALU_MINS   = 'h0E,
        ALU_MAXS   = 'h0F,

        ALU_AND    = 'h10,
        ALU_OR     = 'h11,
        ALU_XOR    = 'h12,
        ALU_NOT    = 'h13,
        ALU_NAND   = 'h14,
        ALU_NOR    = 'h15,
        ALU_XNOR   = 'h16,
        ALU_PASS_A = 'h17,
        ALU_PASS_B = 'h18,

        ALU_SHL    = 'h19,
        ALU_SHR    = 'h1A,
        ALU_SAR    = 'h1B,
        ALU_ROL    = 'h1C,
        ALU_ROR    = 'h1D,

        ALU_EQ     = 'h1E,
        ALU_NE     = 'h1F,
        ALU_LTU    = 'h20,
        ALU_LEU    = 'h21,
        ALU_GTU    = 'h22,
        ALU_GEU    = 'h23,
        ALU_LTS    = 'h24,
        ALU_LES    = 'h25,
        ALU_GTS    = 'h26,
        ALU_GES    = 'h27,

        // Control flow (Stage 6).
        CTRL_JMP   = 'h28,
        CTRL_BEQ   = 'h29,
        CTRL_BNE   = 'h2A,
        CTRL_BLT   = 'h2B,
        CTRL_BGE   = 'h2C,
        CTRL_BLTU  = 'h2D,
        CTRL_BGEU  = 'h2E,

        // Memory (Stage 7). Both use a signed IMMEDIATE_WIDTH byte offset:
        //   LOAD  rd,  [rs1 + imm]
        //   STORE rs2, [rs1 + imm]
        MEM_LOAD   = 'h2F,
        MEM_STORE  = 'h30
    } opcode_t;

    // Encodings the ALU itself executes: 0x00..ALU_GES.
    localparam int ALU_OPCODE_COUNT = int'(ALU_GES) + 1;

    // Number of distinct encodings the OPCODE_WIDTH-bit field can hold.
    localparam logic [OPCODE_WIDTH:0] OPCODE_ENCODINGS = {1'b1, {OPCODE_WIDTH{1'b0}}};

    // ------------------------------------------------------------
    // Opcode classification.
    // ------------------------------------------------------------
    function automatic logic is_valid_opcode(input logic [OPCODE_WIDTH-1:0] op);
        return (op <= MEM_STORE);
    endfunction

    function automatic logic is_valid_alu_opcode(input logic [OPCODE_WIDTH-1:0] op);
        return (op <= ALU_GES);
    endfunction

    function automatic logic is_unary_opcode(input logic [OPCODE_WIDTH-1:0] op);
        return (op == ALU_NEG || op == ALU_ABS || op == ALU_NOT);
    endfunction

    function automatic logic is_mov_op(input logic [OPCODE_WIDTH-1:0] op);
        return (op == ALU_PASS_A);
    endfunction

    function automatic logic is_movi_op(input logic [OPCODE_WIDTH-1:0] op);
        return (op == ALU_PASS_B);
    endfunction

    function automatic logic is_branch_opcode(input logic [OPCODE_WIDTH-1:0] op);
        return (op >= CTRL_JMP && op <= CTRL_BGEU);
    endfunction

    function automatic logic is_memory_opcode(input logic [OPCODE_WIDTH-1:0] op);
        return (op >= MEM_LOAD && op <= MEM_STORE);
    endfunction

endpackage

`endif
