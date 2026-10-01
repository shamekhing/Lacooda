`timescale 1ns/1ps
`ifndef ALU_PKG_SV
`define ALU_PKG_SV

// ============================================================
// ALU package
//
// Owns the ALU status-flag layout only. The opcode map lives in
// opcode_pkg, which is the single source of truth for every opcode.
// ============================================================

package alu_pkg;

    // Status flags, packed MSB-first:
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
    } flags_t;

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

endpackage

`endif
