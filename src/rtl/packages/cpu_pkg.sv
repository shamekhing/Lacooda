`timescale 1ns/1ps
`ifndef CPU_PKG_SV
`define CPU_PKG_SV

// ============================================================
// CPU package
//
// Single source of truth for the LACOODA CPU architecture:
//
//   - architectural word width
//   - architectural word types
//   - register-file geometry
//   - STATUS representation
//   - instruction layout
//   - instruction construction helpers
//
// Memory capacity and memory initialization files DO NOT belong
// here. They are owned by memory_pkg.
//
// Dependency:
//
//     opcode_pkg
//         ↓
//       cpu_pkg
//
// cpu_pkg must therefore NEVER depend on memory_pkg.
// ============================================================

package cpu_pkg;

    import opcode_pkg::*;


    // ========================================================
    // GLOBAL ARCHITECTURAL WORD
    // ========================================================
    //
    // The architectural word is 32 bits.
    // ========================================================

    localparam int WORD_WIDTH = 32;
    localparam int WORD_BYTES = 4;


    // ========================================================
    // ARCHITECTURAL TYPES
    // ========================================================

    typedef logic [WORD_WIDTH-1:0] word_t;

    // An instruction occupies exactly one architectural word.
    typedef word_t instruction_t;


    // ========================================================
    // REGISTER FILE
    // ========================================================

    localparam int REG_FILE_COUNT = 64;

    localparam int REG_FILE_ADDR_WIDTH =
        $clog2(REG_FILE_COUNT);

    typedef logic [REG_FILE_ADDR_WIDTH-1:0] reg_addr_t;


    // R0 is architecturally hardwired to zero.
    localparam reg_addr_t ZERO_REG = '0;


    // ========================================================
    // STATUS REGISTER
    // ========================================================
    //
    // STATUS occupies one architectural word.
    //
    // Implemented state:
    //
    //     [4] DZ
    //     [3] V
    //     [2] C
    //     [1] N
    //     [0] Z
    //
    // Bits [31:5] are reserved.
    // ========================================================

    localparam int STATUS_WIDTH = 32;

    typedef logic [STATUS_WIDTH-1:0] status_t;


    // ALU condition flags.
    typedef struct packed {
        logic Z;
        logic N;
        logic C;
        logic V;
        logic DZ;
    } flags_s;


    function automatic flags_s make_flags(
        input logic z,
        input logic n,
        input logic c,
        input logic v,
        input logic dz
    );

        flags_s f;

        f.Z  = z;
        f.N  = n;
        f.C  = c;
        f.V  = v;
        f.DZ = dz;

        return f;

    endfunction


    // ========================================================
    // INSTRUCTION LAYOUT
    // ========================================================
    //
    // LSB first:
    //
    //     RS2
    //     RS1
    //     RD
    //     OPCODE
    //     I
    //     S
    //     RESERVED
    //
    // For the current 64-register design:
    //
    //     [5:0]    RS2
    //     [11:6]   RS1
    //     [17:12]  RD
    //     [23:18]  OPCODE
    //     [24]     immediate mode
    //     [25]     update STATUS
    //
    // The immediate is NOT packed into the instruction.
    //
    // Instructions requiring an immediate are followed by one
    // complete architectural word containing that immediate.
    // ========================================================

    localparam int RS2_LSB = 0;

    localparam int RS2_MSB =
        RS2_LSB + REG_FILE_ADDR_WIDTH - 1;


    localparam int RS1_LSB =
        RS2_MSB + 1;

    localparam int RS1_MSB =
        RS1_LSB + REG_FILE_ADDR_WIDTH - 1;


    localparam int RD_LSB =
        RS1_MSB + 1;

    localparam int RD_MSB =
        RD_LSB + REG_FILE_ADDR_WIDTH - 1;


    localparam int OPCODE_LSB =
        RD_MSB + 1;

    localparam int OPCODE_MSB =
        OPCODE_LSB + OPCODE_WIDTH - 1;


    localparam int IMM_MODE_BIT =
        OPCODE_MSB + 1;


    localparam int UPDATE_STATUS_BIT =
        IMM_MODE_BIT + 1;


    localparam int RESERVED_LSB =
        UPDATE_STATUS_BIT + 1;

    localparam int RESERVED_MSB =
        WORD_WIDTH - 1;


    // Number of low instruction bits currently assigned meaning.
    localparam int USED_INSTRUCTION_BITS =
        RESERVED_LSB;


    localparam int RESERVED_WIDTH =
        WORD_WIDTH - USED_INSTRUCTION_BITS;


    // ========================================================
    // CPU CONFIGURATION VALIDATION
    // ========================================================
    //
    // IMPORTANT:
    //
    // Only CPU-owned configuration is checked here.
    //
    // Memory capacities are validated by memory_pkg.
    //
    // This avoids:
    //
    //     cpu_pkg -> memory_pkg -> cpu_pkg
    //
    // circular dependencies.
    // ========================================================

    function automatic bit validate_configuration();

        // ----------------------------------------------------
        // Architectural word
        // ----------------------------------------------------

        // ----------------------------------------------------
        // Register file
        // ----------------------------------------------------

        if (REG_FILE_COUNT < 2)
            $fatal(
                1,
                "REG_FILE_COUNT must be at least 2"
            );


        // ----------------------------------------------------
        // Opcode encoding
        // ----------------------------------------------------

        if (OPCODE_WIDTH < $clog2('h31))
            $fatal(
                1,
                "OPCODE_WIDTH cannot represent existing opcodes"
            );


        // ----------------------------------------------------
        // Instruction layout
        // ----------------------------------------------------

        if (USED_INSTRUCTION_BITS > WORD_WIDTH)
            $fatal(
                1,
                "Instruction fields exceed WORD_WIDTH"
            );


        return 1'b1;

    endfunction


    // ========================================================
    // PACKED INSTRUCTION FIELDS
    // ========================================================

    typedef struct packed {

        logic      update_status;
        logic      immediate_mode;

        opcode_t   opcode;

        reg_addr_t rd;
        reg_addr_t rs1;
        reg_addr_t rs2;

    } instruction_s;


    // ========================================================
    // IMMEDIATE PRESENCE
    // ========================================================
    //
    // An instruction has a following immediate word when it is:
    //
    //   - a branch/jump
    //   - LOAD/STORE
    //   - an ALU operation using immediate mode
    // ========================================================

    function automatic logic uses_imm(
        input opcode_t opcode,
        input logic    immediate_mode
    );

        return (
            is_branch_opcode(opcode) ||
            is_memory_opcode(opcode) ||
            immediate_mode
        );

    endfunction


    function automatic logic instr_uses_imm(
        input instruction_t instruction
    );

        instruction_s instr_fields;

        instr_fields = instruction;

        return uses_imm(
            instr_fields.opcode,
            instr_fields.immediate_mode
        );

    endfunction


    // ========================================================
    // GENERIC INSTRUCTION ENCODER
    // ========================================================

    function automatic instruction_t encode_instruction(

        input opcode_t   opcode,

        input reg_addr_t rd,
        input reg_addr_t rs1,
        input reg_addr_t rs2,

        input logic      immediate_mode,
        input logic      update_status

    );

        instruction_s instr_fields;

        instr_fields = '0;

        instr_fields.opcode         = opcode;
        instr_fields.rd             = rd;
        instr_fields.rs1            = rs1;
        instr_fields.rs2            = rs2;
        instr_fields.immediate_mode = immediate_mode;
        instr_fields.update_status  = update_status;

        return instruction_t'(instr_fields);

    endfunction


    // ========================================================
    // BRANCH ENCODER
    // ========================================================

    function automatic instruction_t encode_branch(

        input opcode_t   opcode,
        input reg_addr_t rs1,
        input reg_addr_t rs2

    );

        instruction_s instr_fields;

        instr_fields = '0;

        instr_fields.opcode = opcode;
        instr_fields.rs1    = rs1;
        instr_fields.rs2    = rs2;

        return instruction_t'(instr_fields);

    endfunction


    // ========================================================
    // JUMP ENCODER
    // ========================================================

    function automatic instruction_t encode_jump();

        return encode_branch(
            CTRL_JMP,
            ZERO_REG,
            ZERO_REG
        );

    endfunction


    // ========================================================
    // LOAD ENCODER
    //
    //     LOAD rd, [base + offset]
    //
    // The signed byte offset occupies the following word.
    // ========================================================

    function automatic instruction_t encode_load(

        input reg_addr_t rd,
        input reg_addr_t base

    );

        instruction_s instr_fields;

        instr_fields = '0;

        instr_fields.opcode = MEM_LOAD;
        instr_fields.rd     = rd;
        instr_fields.rs1    = base;

        return instruction_t'(instr_fields);

    endfunction


    // ========================================================
    // STORE ENCODER
    //
    //     STORE source, [base + offset]
    //
    // The signed byte offset occupies the following word.
    // ========================================================

    function automatic instruction_t encode_store(

        input reg_addr_t source,
        input reg_addr_t base

    );

        instruction_s instr_fields;

        instr_fields = '0;

        instr_fields.opcode = MEM_STORE;
        instr_fields.rs1    = base;
        instr_fields.rs2    = source;

        return instruction_t'(instr_fields);

    endfunction

endpackage

`endif
