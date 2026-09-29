`timescale 1ns/1ps

// ============================================================
// Instruction decoder
//
// Splits a 64-bit instruction into its fields, validates the
// operand format and produces the datapath control signals.
//
// Format rules per instruction class:
//   MOV (PASS_A) & unary ops : operand A = RS1; no immediate;
//                              RS2 and IMM32 must be zero
//   MOVI (PASS_B)            : operand B = sign-extended IMM32;
//                              immediate mode required; RS1/RS2 zero
//   binary ops               : register mode needs IMM32 = 0;
//                              immediate mode needs RS2 = 0
//
// In addition: reserved bits must be zero and MOV/MOVI must not
// update the status register. Any violation clears every control
// output and raises illegal_instruction.
//
// The opcode-classification helpers live here because the decoder
// is their only consumer.
// ============================================================

module decoder (
    input  cpu_pkg::instruction_t instruction,

    output cpu_pkg::reg_addr_t rs1,
    output cpu_pkg::reg_addr_t rs2,
    output cpu_pkg::reg_addr_t rd,

    output alu_pkg::opcode_t alu_op,
    output cpu_pkg::data_t immediate,
    output logic        use_immediate,

    output logic        register_write_enable,
    output logic        flags_write_enable,

    output logic        instruction_valid,
    output logic        illegal_instruction
);

    import cpu_pkg::*;
    import alu_pkg::*;

    instruction_fields_t fields;

    logic opcode_valid;
    logic format_valid;
    logic unary_op;
    logic mov_op;
    logic movi_op;

    // ------------------------------------------------------------
    // Opcode classification (moved here from alu_pkg).
    // ------------------------------------------------------------

    function automatic logic is_valid_opcode(input alu_pkg::opcode_t op);
        return (op <= ALU_GES);
    endfunction

    function automatic logic is_unary_opcode(input alu_pkg::opcode_t op);
        return (op == ALU_NEG || op == ALU_ABS || op == ALU_NOT);
    endfunction

    function automatic logic is_mov_op(input alu_pkg::opcode_t op);
        return (op == ALU_PASS_A);
    endfunction

    function automatic logic is_movi_op(input alu_pkg::opcode_t op);
        return (op == ALU_PASS_B);
    endfunction

    // ------------------------------------------------------------
    // Extract the complete instruction.
    // ------------------------------------------------------------

    assign fields = instruction;

    // ------------------------------------------------------------
    // Validate opcode and operand format.
    // ------------------------------------------------------------
    always_comb begin

        opcode_valid = is_valid_opcode(fields.opcode);

        unary_op = is_unary_opcode(fields.opcode);

        mov_op  = is_mov_op(fields.opcode);
        movi_op = is_movi_op(fields.opcode);

        format_valid = opcode_valid;

        // Reserved bits must be zero.
        if (fields.reserved != '0)
            format_valid = 1'b0;

        // MOV and MOVI preserve status.
        if ((mov_op || movi_op) && fields.update_status)
            format_valid = 1'b0;

        if (mov_op || unary_op) begin

            // Operand A = RS1.
            // Operand B is unused.
            if (fields.immediate_mode)
                format_valid = 1'b0;

            if (fields.rs2 != '0)
                format_valid = 1'b0;

            if (fields.imm32 != '0)
                format_valid = 1'b0;

        end else if (movi_op) begin

            // Operand B = sign-extended IMM32.
            // Both source register fields are unused.
            if (!fields.immediate_mode)
                format_valid = 1'b0;

            if (fields.rs1 != '0)
                format_valid = 1'b0;

            if (fields.rs2 != '0)
                format_valid = 1'b0;

        end else begin

            // Binary ALU operation.
            if (fields.immediate_mode) begin

                // Immediate replaces RS2.
                if (fields.rs2 != '0)
                    format_valid = 1'b0;

            end else begin

                // Register-register mode.
                if (fields.imm32 != '0)
                    format_valid = 1'b0;

            end

        end

    end

    // ------------------------------------------------------------
    // Generate datapath controls.
    //
    // All outputs are disabled for an invalid instruction.
    // ------------------------------------------------------------

    always_comb begin

        rs1 = '0;
        rs2 = '0;
        rd  = '0;

        alu_op        = alu_pkg::opcode_t'(0);
        immediate     = '0;
        use_immediate = 1'b0;

        register_write_enable = 1'b0;
        flags_write_enable    = 1'b0;

        instruction_valid   = 1'b0;
        illegal_instruction = 1'b1;

        if (format_valid) begin

            rs1 = fields.rs1;
            rs2 = fields.rs2;
            rd  = fields.rd;

            alu_op = fields.opcode;

            immediate = sign_extend_imm32(fields.imm32);

            use_immediate = fields.immediate_mode;

            register_write_enable = 1'b1;
            flags_write_enable    = fields.update_status;

            instruction_valid   = 1'b1;
            illegal_instruction = 1'b0;

        end

    end

endmodule
