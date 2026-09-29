`timescale 1ns/1ps

module decoder_tb;

    import cpu_pkg::*;
    import alu_pkg::*;

    cpu_pkg::instruction_t instruction;

    cpu_pkg::reg_addr_t rs1;
    cpu_pkg::reg_addr_t rs2;
    cpu_pkg::reg_addr_t rd;

    alu_pkg::opcode_t alu_op;
    cpu_pkg::data_t   immediate;
    logic             use_immediate;

    logic             register_write_enable;
    logic             flags_write_enable;

    logic             instruction_valid;
    logic             illegal_instruction;

    integer tests  = 0;
    integer errors = 0;

    decoder dut (
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .alu_op(alu_op),
        .immediate(immediate),
        .use_immediate(use_immediate),
        .register_write_enable(register_write_enable),
        .flags_write_enable(flags_write_enable),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction)
    );

    task automatic check(input logic condition, input string description);
        begin
            #1;
            tests = tests + 1;
            if (!condition) begin
                errors = errors + 1;
                $display("FAIL %0d %s", tests, description);
            end else begin
                $display("PASS %0d %s", tests, description);
            end
        end
    endtask

    initial begin
        $dumpfile("decoder_tb.vcd");
        $dumpvars(0, decoder_tb);

        instruction = '0;

        // 1. Register-register ADD.
        instruction = cpu_pkg::encode_instruction(
            ALU_ADD, 6'd1, 6'd2, 6'd3, 1'b0, 1'b1, 32'd0);
        #1;
        check(instruction_valid === 1'b1,     "ADD rr is valid");
        check(illegal_instruction === 1'b0,   "ADD rr is legal");
        check(rs1 === 6'd2,                   "ADD rr rs1");
        check(rs2 === 6'd3,                   "ADD rr rs2");
        check(rd  === 6'd1,                   "ADD rr rd");
        check(alu_op === ALU_ADD,             "ADD rr opcode");
        check(use_immediate === 1'b0,         "ADD rr register mode");
        check(register_write_enable === 1'b1, "ADD rr writes rd");
        check(flags_write_enable === 1'b1,    "ADD rr updates flags");

        // 2. Immediate ADD with a negative immediate.
        instruction = cpu_pkg::encode_instruction(
            ALU_ADD, 6'd5, 6'd6, 6'd0, 1'b1, 1'b1, 32'hFFFFFFFF);
        #1;
        check(instruction_valid === 1'b1,          "ADDI is valid");
        check(use_immediate === 1'b1,              "ADDI uses immediate");
        check(immediate === 64'hFFFFFFFFFFFFFFFF,  "ADDI sign extension");

        // 3. MOV (PASS_A) preserves the status register.
        instruction = cpu_pkg::encode_instruction(
            ALU_PASS_A, 6'd7, 6'd8, 6'd0, 1'b0, 1'b0, 32'd0);
        #1;
        check(instruction_valid === 1'b1,     "MOV is valid");
        check(register_write_enable === 1'b1, "MOV writes rd");
        check(flags_write_enable === 1'b0,    "MOV preserves flags");

        // 4. MOV must not update the status register.
        instruction = cpu_pkg::encode_instruction(
            ALU_PASS_A, 6'd7, 6'd8, 6'd0, 1'b0, 1'b1, 32'd0);
        #1;
        check(instruction_valid === 1'b0,   "MOV + status is invalid");
        check(illegal_instruction === 1'b1, "MOV + status is illegal");

        // 5. MOVI (PASS_B) with an immediate.
        instruction = cpu_pkg::encode_instruction(
            ALU_PASS_B, 6'd9, 6'd0, 6'd0, 1'b1, 1'b0, 32'h0000007F);
        #1;
        check(instruction_valid === 1'b1,          "MOVI is valid");
        check(use_immediate === 1'b1,              "MOVI uses immediate");
        check(immediate === 64'h000000000000007F,  "MOVI immediate value");

        // 6. Unary NEG (operand A = RS1, no immediate).
        instruction = cpu_pkg::encode_instruction(
            ALU_NEG, 6'd2, 6'd3, 6'd0, 1'b0, 1'b1, 32'd0);
        #1;
        check(instruction_valid === 1'b1, "NEG is valid");

        // 7. Unary NEG with a non-zero RS2 is invalid.
        instruction = cpu_pkg::encode_instruction(
            ALU_NEG, 6'd2, 6'd3, 6'd4, 1'b0, 1'b1, 32'd0);
        #1;
        check(instruction_valid === 1'b0, "NEG + RS2 is invalid");

        // 8. Register-register op with a non-zero immediate is invalid.
        instruction = cpu_pkg::encode_instruction(
            ALU_ADD, 6'd1, 6'd2, 6'd3, 1'b0, 1'b1, 32'h00000001);
        #1;
        check(instruction_valid === 1'b0, "ADD rr + immediate is invalid");

        // 9. Reserved bits must be zero.
        instruction = '0;
        instruction[63] = 1'b1;
        #1;
        check(instruction_valid === 1'b0, "reserved bits set is invalid");

        // 10. Unknown opcode encoding.
        instruction = '0;
        instruction[50 +: 6] = 6'h3F;
        #1;
        check(instruction_valid === 1'b0,   "unknown opcode is invalid");
        check(illegal_instruction === 1'b1, "unknown opcode is illegal");

        // 11. Invalid encodings disable the datapath controls.
        check(register_write_enable === 1'b0, "invalid disables rd write");
        check(flags_write_enable === 1'b0,    "invalid disables flag write");

        $display("----------------------------------------");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests - errors);
        $display("Failed      : %0d", errors);
        $display("----------------------------------------");

        if (errors != 0)
            $fatal(1, "DECODER TEST FAILED");

        $display("ALL DECODER TESTS PASSED");
        $finish;
    end

endmodule
