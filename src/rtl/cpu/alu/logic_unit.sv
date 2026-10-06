`timescale 1ns/1ps
// ============================================================
// ALU bitwise-logic sub-unit (bit-serial, multi-cycle)
//
// One bit is processed per clock, LSB-first, so the unit is just a
// two shift registers, a result register and a 1-bit logic function.
// Operations: AND/OR/XOR/NOT/NAND/NOR/XNOR plus the PASS_A/PASS_B
// paths used to implement MOV (PASS_A) and MOVI (PASS_B).
// ============================================================

module logic_unit (
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,

    output cpu_pkg::word_t result,
    output logic busy,
    output logic done
);

    import cpu_pkg::*;
    import opcode_pkg::*;
    import alu_pkg::*;

    alu_state_e state;

    logic [cpu_pkg::WORD_WIDTH-1:0] a_sr, b_sr, r_sr;
    logic [SERIAL_WIDTH-1:0]        cnt;

    logic a_bit, b_bit, out_bit;

    assign a_bit = a_sr[0];
    assign b_bit = b_sr[0];

    assign result = r_sr;
    assign busy   = (state != S_IDLE);
    assign done   = (state == S_DONE);

    always_comb begin
        case (op)
            ALU_NOT:    out_bit = ~a_bit;
            ALU_AND:    out_bit = a_bit & b_bit;
            ALU_OR:     out_bit = a_bit | b_bit;
            ALU_XOR:    out_bit = a_bit ^ b_bit;
            ALU_NAND:   out_bit = ~(a_bit & b_bit);
            ALU_NOR:    out_bit = ~(a_bit | b_bit);
            ALU_XNOR:   out_bit = ~(a_bit ^ b_bit);
            ALU_PASS_A: out_bit = a_bit;
            ALU_PASS_B: out_bit = b_bit;
            default:    out_bit = 1'b0;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            cnt   <= '0;
            a_sr  <= '0;
            b_sr  <= '0;
            r_sr  <= '0;
        end else begin
            case (state)

                S_IDLE: begin
                    if (start) begin
                        a_sr  <= operand_a;
                        b_sr  <= operand_b;
                        r_sr  <= '0;
                        cnt   <= '0;
                        state <= S_RUN;
                    end
                end

                S_RUN: begin
                    a_sr <= {1'b0, a_sr[cpu_pkg::WORD_WIDTH-1:1]};
                    b_sr <= {1'b0, b_sr[cpu_pkg::WORD_WIDTH-1:1]};
                    r_sr <= {out_bit, r_sr[cpu_pkg::WORD_WIDTH-1:1]};

                    if (cnt == cpu_pkg::WORD_WIDTH - 1)
                        state <= S_DONE;
                    else
                        cnt <= cnt + 1'b1;
                end

                S_DONE: state <= S_IDLE;

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
