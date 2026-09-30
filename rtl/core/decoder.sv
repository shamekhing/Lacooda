`timescale 1ns/1ps

// ============================================================
// Instruction decoder — Stage 6
//
// Decodes both the original ALU instructions and the new control-flow
// instructions without changing the existing 64-bit instruction layout.
//
// ALU format rules:
//   MOV (PASS_A) & unary ops : operand A = RS1; no immediate;
//                              RS2 and IMM32 must be zero
//   MOVI (PASS_B)            : operand B = sign-extended IMM32;
//                              immediate mode required; RS1/RS2 zero
//   binary ops               : register mode needs IMM32 = 0;
//                              immediate mode needs RS2 = 0
//
// Stage-6 control-flow rules:
//   JMP                      : RD/RS1/RS2/I/S = 0; IMM32 = target
//   BEQ/BNE/BLT/BGE/...      : RD/I/S = 0; RS1/RS2 are compared;
//                              IMM32 = absolute byte target
//
// Reserved bits must always be zero. Invalid encodings clear every
// control output and raise illegal_instruction.
// ============================================================

module decoder (
    input  cpu_pkg::instruction_t instruction,

    output cpu_pkg::reg_addr_t rs1,
    output cpu_pkg::reg_addr_t rs2,
    output cpu_pkg::reg_addr_t rd,

    output alu_pkg::opcode_t alu_op,
    output cpu_pkg::data_t immediate,
    output logic use_immediate,

    output logic register_write_enable,
    output logic flags_write_enable,

    // Stage 6 control-flow outputs.
    output logic branch_enable,
    output cpu_pkg::branch_condition_t branch_condition,
    output cpu_pkg::data_t branch_target,

    output logic instruction_valid,
    output logic illegal_instruction
);

    import cpu_pkg::*;
    import alu_pkg::*;

    instruction_fields_t fields;

    logic opcode_valid;
    logic format_valid;
    logic unary_op;
    logic mov_op;
    logic movi_op;
    logic branch_op;

    // ------------------------------------------------------------
    // Opcode classification.
    // ------------------------------------------------------------
    function automatic logic is_valid_alu_opcode(input instruction_opcode_t op);
        return (op <= ALU_GES);
    endfunction

    function automatic logic is_unary_opcode(input instruction_opcode_t op);
        return (op == ALU_NEG || op == ALU_ABS || op == ALU_NOT);
    endfunction

    function automatic logic is_mov_op(input instruction_opcode_t op);
        return (op == ALU_PASS_A);
    endfunction

    function automatic logic is_movi_op(input instruction_opcode_t op);
        return (op == ALU_PASS_B);
    endfunction

    function automatic logic is_branch_opcode(input instruction_opcode_t op);
        return (
            op == CTRL_JMP  ||
            op == CTRL_BEQ  ||
            op == CTRL_BNE  ||
            op == CTRL_BLT  ||
            op == CTRL_BGE  ||
            op == CTRL_BLTU ||
            op == CTRL_BGEU
        );
    endfunction

    // Packed struct overlay: no hardcoded instruction bit slicing here.
    assign fields = instruction;

    // ------------------------------------------------------------
    // Validate opcode and operand format.
    // ------------------------------------------------------------
    always_comb begin
        branch_op = is_branch_opcode(fields.opcode);
        opcode_valid = is_valid_alu_opcode(fields.opcode) || branch_op;

        unary_op = is_unary_opcode(fields.opcode);
        mov_op   = is_mov_op(fields.opcode);
        movi_op  = is_movi_op(fields.opcode);

        format_valid = opcode_valid;

        // Every currently defined instruction requires reserved bits 0.
        if ((instruction >> USED_INSTRUCTION_BITS) != '0)
            format_valid = 1'b0;

        // Non-power-of-two register counts leave unused address encodings.
        if (fields.rd >= REG_COUNT || fields.rs1 >= REG_COUNT || fields.rs2 >= REG_COUNT)
            format_valid = 1'b0;

        if (branch_op) begin
            // Branches/jumps never write an ALU destination register and
            // never use the ALU immediate/status mode bits.
            if (fields.rd != ZERO_REG)
                format_valid = 1'b0;
            if (fields.immediate_mode)
                format_valid = 1'b0;
            if (fields.update_status)
                format_valid = 1'b0;

            // JMP consumes no register operands. Conditional branches do.
            if (fields.opcode == CTRL_JMP) begin
                if (fields.rs1 != ZERO_REG)
                    format_valid = 1'b0;
                if (fields.rs2 != ZERO_REG)
                    format_valid = 1'b0;
            end

        end else begin
            // MOV and MOVI preserve status.
            if ((mov_op || movi_op) && fields.update_status)
                format_valid = 1'b0;

            if (mov_op || unary_op) begin
                // Operand A = RS1. Operand B and immediate are unused.
                if (fields.immediate_mode)
                    format_valid = 1'b0;
                if (fields.rs2 != ZERO_REG)
                    format_valid = 1'b0;
                if (fields.imm32 != '0)
                    format_valid = 1'b0;

            end else if (movi_op) begin
                // Operand B = sign-extended IMM32. Sources are unused.
                if (!fields.immediate_mode)
                    format_valid = 1'b0;
                if (fields.rs1 != ZERO_REG)
                    format_valid = 1'b0;
                if (fields.rs2 != ZERO_REG)
                    format_valid = 1'b0;

            end else begin
                // Binary ALU operation.
                if (fields.immediate_mode) begin
                    // Immediate replaces RS2.
                    if (fields.rs2 != ZERO_REG)
                        format_valid = 1'b0;
                end else begin
                    // Register-register mode has no immediate payload.
                    if (fields.imm32 != '0)
                        format_valid = 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Generate datapath/control-flow controls.
    // ------------------------------------------------------------
    always_comb begin
        // Safe defaults used for every illegal instruction.
        rs1 = ZERO_REG;
        rs2 = ZERO_REG;
        rd  = ZERO_REG;

        alu_op        = ALU_ADD;
        immediate     = '0;
        use_immediate = 1'b0;

        register_write_enable = 1'b0;
        flags_write_enable    = 1'b0;

        branch_enable    = 1'b0;
        branch_condition = BR_ALWAYS;
        branch_target    = '0;

        instruction_valid   = 1'b0;
        illegal_instruction = 1'b1;

        if (format_valid) begin
            if (branch_op) begin
                // Source addresses feed the existing register file, so the
                // branch unit receives the actual register values through
                // datapath operand_a/operand_b.
                rs1 = fields.rs1;
                rs2 = fields.rs2;

                branch_enable = 1'b1;
                // Targets are absolute byte addresses; decoding does not validate
                // their alignment or whether they fit in instruction memory.
                branch_target = zero_extend_target(fields.imm32);

                case (fields.opcode)
                    CTRL_JMP:  branch_condition = BR_ALWAYS;
                    CTRL_BEQ:  branch_condition = BR_EQ;
                    CTRL_BNE:  branch_condition = BR_NE;
                    CTRL_BLT:  branch_condition = BR_LT;
                    CTRL_BGE:  branch_condition = BR_GE;
                    CTRL_BLTU: branch_condition = BR_LTU;
                    CTRL_BGEU: branch_condition = BR_GEU;
                    default:   branch_condition = BR_ALWAYS;
                endcase

                // register_write_enable and flags_write_enable remain 0.
            end else begin
                // Original ALU path is unchanged.
                rs1 = fields.rs1;
                rs2 = fields.rs2;
                rd  = fields.rd;

                alu_op = opcode_t'(fields.opcode);
                immediate = sign_extend_imm32(fields.imm32);
                use_immediate = fields.immediate_mode;

                register_write_enable = 1'b1;
                flags_write_enable = fields.update_status;
            end

            instruction_valid   = 1'b1;
            illegal_instruction = 1'b0;
        end
    end

endmodule
