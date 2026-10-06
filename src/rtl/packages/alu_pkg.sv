`timescale 1ns/1ps
`ifndef ALU_PKG_SV
`define ALU_PKG_SV

// ============================================================
// ALU package
//
// Shared constants, the sequencer state type and the two load-time
// bit helpers the four bit-serial ALU sub-units would otherwise each
// duplicate. It does not replace cpu_pkg or opcode_pkg; those stay the
// single source of truth for the architectural word and the opcode map.
//
// NOTE: the per-cycle serialiser steps (shift/rotate/push) are written
// inline in the sub-units rather than as package functions. iverilog (the
// regression simulator) mis-schedules package-function calls used inside
// always_comb across multiple instances, so the hot path avoids them.
// ============================================================

package alu_pkg;

    // Serial index / shift-amount width (matches the original shifter).
    localparam int SERIAL_WIDTH = $clog2(cpu_pkg::WORD_WIDTH);

    // Sign-related bit patterns.
    localparam logic [cpu_pkg::WORD_WIDTH-1:0] MSB_ONE =
        {1'b1, {(cpu_pkg::WORD_WIDTH-1){1'b0}}};

    localparam logic [cpu_pkg::WORD_WIDTH-1:0] ALL_ONES =
        {cpu_pkg::WORD_WIDTH{1'b1}};

    // Common sequencer states shared by every sub-unit.
    typedef enum logic [1:0] {
        S_IDLE,
        S_RUN,
        S_DONE
    } alu_state_e;

    // Reverse a word (used at load time to stream MSB-first).
    function automatic logic [cpu_pkg::WORD_WIDTH-1:0] rev(
        input logic [cpu_pkg::WORD_WIDTH-1:0] x);
        integer i;
        for (i = 0; i < cpu_pkg::WORD_WIDTH; i = i + 1)
            rev[i] = x[cpu_pkg::WORD_WIDTH-1-i];
        return rev;
    endfunction

    // Two's-complement negation.
    function automatic logic [cpu_pkg::WORD_WIDTH-1:0] twos_neg(
        input logic [cpu_pkg::WORD_WIDTH-1:0] x);
        return (~x) + 1'b1;
    endfunction

endpackage

`endif
