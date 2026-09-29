
`ifndef ALU_PKG_SV
`define ALU_PKG_SV

package alu_pkg;

    // ============================================================
    // ALU configuration — single source of truth
    // ============================================================

    localparam int OPCODE_WIDTH = 6;

    typedef struct packed {
        logic Z;
        logic N;
        logic C;
        logic V;
        logic DZ;
    } flags_t;

    localparam int FLAGS_WIDTH = $bits(flags_t);

    function automatic flags_t make_flags(
        input logic z, n, c, v, dz
    );
        flags_t f;
        f.Z  = z;
        f.N  = n;
        f.C  = c;
        f.V  = v;
        f.DZ = dz;
        return f;
    endfunction

    // ============================================================
    // Existing ALU opcodes — numbering preserved
    // ============================================================

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
        ALU_GES    = 'h27
    } opcode_t;

    localparam int OPCODE_COUNT = int'(ALU_GES) + 1;
    localparam int OPCODE_ENCODINGS = 1 << OPCODE_WIDTH;

endpackage

`endif
