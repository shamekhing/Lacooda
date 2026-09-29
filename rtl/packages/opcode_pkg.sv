
`ifndef OPCODE_PKG_SV
`define OPCODE_PKG_SV

package opcode_pkg;

    typedef enum logic [5:0] {

        // Arithmetic
        ALU_ADD    = 6'h00,
        ALU_ADC    = 6'h01,
        ALU_SUB    = 6'h02,
        ALU_SBC    = 6'h03,
        ALU_MUL    = 6'h04,
        ALU_MULH   = 6'h05,
        ALU_DIVU   = 6'h06,
        ALU_MODU   = 6'h07,
        ALU_DIVS   = 6'h08,
        ALU_MODS   = 6'h09,
        ALU_NEG    = 6'h0A,
        ALU_ABS    = 6'h0B,
        ALU_MINU   = 6'h0C,
        ALU_MAXU   = 6'h0D,
        ALU_MINS   = 6'h0E,
        ALU_MAXS   = 6'h0F,

        // Bitwise logic
        ALU_AND    = 6'h10,
        ALU_OR     = 6'h11,
        ALU_XOR    = 6'h12,
        ALU_NOT    = 6'h13,
        ALU_NAND   = 6'h14,
        ALU_NOR    = 6'h15,
        ALU_XNOR   = 6'h16,
        ALU_PASS_A = 6'h17,
        ALU_PASS_B = 6'h18,

        // Shifts and rotations
        ALU_SHL    = 6'h19,
        ALU_SHR    = 6'h1A,
        ALU_SAR    = 6'h1B,
        ALU_ROL    = 6'h1C,
        ALU_ROR    = 6'h1D,

        // Comparisons
        ALU_EQ     = 6'h1E,
        ALU_NE     = 6'h1F,
        ALU_LTU    = 6'h20,
        ALU_LEU    = 6'h21,
        ALU_GTU    = 6'h22,
        ALU_GEU    = 6'h23,
        ALU_LTS    = 6'h24,
        ALU_LES    = 6'h25,
        ALU_GTS    = 6'h26,
        ALU_GES    = 6'h27

    } alu_op_t;

endpackage

`endif
