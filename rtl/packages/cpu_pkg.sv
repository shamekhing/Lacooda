`timescale 1ns/1ps
`ifndef CPU_PKG_SV
`define CPU_PKG_SV

package cpu_pkg;

    import alu_pkg::*;

    localparam int DATA_WIDTH = 64;
    localparam int REG_COUNT = 64;
    localparam int INSTRUCTION_WIDTH = 64;
    localparam int IMMEDIATE_WIDTH = 32;
    localparam int REG_ADDR_WIDTH = $clog2(REG_COUNT);

    typedef logic [DATA_WIDTH-1:0] data_t;
    typedef logic [REG_ADDR_WIDTH-1:0] reg_addr_t;
    typedef logic [INSTRUCTION_WIDTH-1:0] instruction_t;
    typedef logic [IMMEDIATE_WIDTH-1:0] imm_t;
    localparam reg_addr_t ZERO_REG = '0;

    localparam int IMM_LSB = 0;
    localparam int IMM_MSB = IMM_LSB + IMMEDIATE_WIDTH - 1;
    localparam int RS2_LSB = IMM_MSB + 1;
    localparam int RS2_MSB = RS2_LSB + REG_ADDR_WIDTH - 1;
    localparam int RS1_LSB = RS2_MSB + 1;
    localparam int RS1_MSB = RS1_LSB + REG_ADDR_WIDTH - 1;
    localparam int RD_LSB = RS1_MSB + 1;
    localparam int RD_MSB = RD_LSB + REG_ADDR_WIDTH - 1;
    localparam int OPCODE_LSB = RD_MSB + 1;
    localparam int OPCODE_MSB = OPCODE_LSB + OPCODE_WIDTH - 1;
    localparam int I_BIT = OPCODE_MSB + 1;
    localparam int S_BIT = I_BIT + 1;
    localparam int RESERVED_LSB = S_BIT + 1;
    localparam int RESERVED_MSB = INSTRUCTION_WIDTH - 1;
    localparam int RESERVED_WIDTH = INSTRUCTION_WIDTH - RESERVED_LSB;

    typedef struct packed {
        logic [RESERVED_WIDTH-1:0] reserved;
        logic update_status;
        logic immediate_mode;
        opcode_t opcode;
        reg_addr_t rd;
        reg_addr_t rs1;
        reg_addr_t rs2;
        imm_t imm32;
    } instruction_fields_t;

    function automatic data_t sign_extend_imm32(input imm_t value);
        return {{(DATA_WIDTH-IMMEDIATE_WIDTH){value[IMMEDIATE_WIDTH-1]}}, value};
    endfunction

    function automatic instruction_t encode_instruction(
        input opcode_t opcode,
        input reg_addr_t rd, rs1, rs2,
        input logic immediate_mode, update_status,
        input imm_t imm32
    );
        instruction_fields_t fields;
        fields = '0;
        fields.opcode = opcode;
        fields.rd = rd;
        fields.rs1 = rs1;
        fields.rs2 = rs2;
        fields.immediate_mode = immediate_mode;
        fields.update_status = update_status;
        fields.imm32 = imm32;
        return fields;
    endfunction
endpackage
`endif
