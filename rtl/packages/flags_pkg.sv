`ifndef FLAGS_PKG_SV
`define FLAGS_PKG_SV

package flags_pkg;
typedef struct packed {
        logic Z;   // Result is zero
        logic N;   // Result's most significant bit
        logic C;   // Carry / no borrow
        logic V;   // Signed overflow
        logic DZ;  // Division by zero
    } flags_t;
endpackage

`endif
