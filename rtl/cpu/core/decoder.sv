`timescale 1ns/1ps

// ============================================================
// Instruction decoder — Stage 7
//
// Decodes the existing ALU/control-flow instructions plus Stage-7
// LOAD/STORE without changing the instruction layout.
//
// Stage-7 memory formats:
//   LOAD  rd, [rs1 + imm] : RD=destination, RS1=base, RS2=0,
//                            I=0, S=0, IMM=signed byte offset
//   STORE rs2,[rs1 + imm] : RD=0, RS1=base, RS2=source,
//                            I=0, S=0, IMM=signed byte offset
//
// LOAD/STORE use ALU_ADD internally to calculate the effective byte
// address. STORE still reads RS2 through the register file's second
// read port; datapath exposes that raw value separately as store_data.
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

    // Stage 7 memory controls.
    output logic memory_read_enable,
    output logic memory_write_enable,

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
    logic memory_op;
    logic load_op;
    logic store_op;

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

    function automatic logic is_memory_opcode(input instruction_opcode_t op);
        return (op == MEM_LOAD || op == MEM_STORE);
    endfunction

    // Packed struct overlay: no hardcoded instruction bit slicing here.
    assign fields = instruction;

    // ------------------------------------------------------------
    // Validate opcode and operand format.
    // ------------------------------------------------------------
    always_comb begin
        branch_op = is_branch_opcode(fields.opcode);
        memory_op = is_memory_opcode(fields.opcode);
        load_op   = (fields.opcode == MEM_LOAD);
        store_op  = (fields.opcode == MEM_STORE);

        opcode_valid = is_valid_alu_opcode(fields.opcode) || branch_op || memory_op;

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
            // Branches/jumps never write a destination register and do not
            // use the normal ALU immediate/status mode bits.
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

        end else if (memory_op) begin
            // LOAD/STORE always use their encoded IMM32 as a signed byte
            // offset, so the normal ALU immediate/status bits stay zero.
            if (fields.immediate_mode)
                format_valid = 1'b0;
            if (fields.update_status)
                format_valid = 1'b0;

            if (load_op) begin
                // LOAD uses RD as destination and RS1 as base. RS2 is unused.
                if (fields.rs2 != ZERO_REG)
                    format_valid = 1'b0;
            end else if (store_op) begin
                // STORE uses RS1 as base and RS2 as source. RD is unused.
                if (fields.rd != ZERO_REG)
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
    // Generate datapath/control-flow/memory controls.
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

        memory_read_enable  = 1'b0;
        memory_write_enable = 1'b0;

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

            end else if (memory_op) begin
                // The existing ALU calculates base + signed byte offset.
                rs1 = fields.rs1;
                rs2 = fields.rs2;
                rd  = fields.rd;

                alu_op        = ALU_ADD;
                immediate     = sign_extend_imm32(fields.imm32);
                use_immediate = 1'b1;

                if (load_op) begin
                    memory_read_enable    = 1'b1;
                    register_write_enable = 1'b1;
                end else begin
                    memory_write_enable = 1'b1;
                end

                // Memory instructions do not update status flags.
                flags_write_enable = 1'b0;

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
