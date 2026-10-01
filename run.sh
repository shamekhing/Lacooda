#!/bin/bash
# LACOODA regression runner.
# Run from the repository root so source paths and ROM initialization resolve.
set -e

mkdir -p sim/build sim/waveforms

run_test() {
    local label="$1"
    local top="$2"
    local binary="$3"
    local vcd="$4"
    shift 4

    echo "========== ${label} =========="

    iverilog -g2012 -Wall \
        -s "$top" \
        -o "sim/build/$binary" \
        "$@"

    vvp "sim/build/$binary"

    if [[ -f "$vcd" ]]; then
        mv -f "$vcd" "sim/waveforms/$vcd"
    fi
}

run_test "ALU TEST" alu_tb alu_sim alu.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/alu/arithmetic.sv \
    rtl/cpu/alu/logic_unit.sv \
    rtl/cpu/alu/shifter.sv \
    rtl/cpu/alu/comparator.sv \
    rtl/cpu/alu/alu.sv \
    rtl/cpu/core/status_register.sv \
    sim/testbench/cpu/alu_tb.sv

run_test "REGISTER FILE TEST" register_file_tb register_file_sim register_file.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/core/register_file.sv \
    sim/testbench/cpu/register_file_tb.sv

run_test "DATAPATH TEST" datapath_tb datapath_sim datapath.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/alu/arithmetic.sv \
    rtl/cpu/alu/logic_unit.sv \
    rtl/cpu/alu/shifter.sv \
    rtl/cpu/alu/comparator.sv \
    rtl/cpu/alu/alu.sv \
    rtl/cpu/core/register_file.sv \
    rtl/cpu/core/status_register.sv \
    rtl/cpu/core/datapath.sv \
    sim/testbench/cpu/datapath_tb.sv

run_test "DECODER TEST" decoder_tb decoder_sim decoder_tb.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/core/decoder.sv \
    sim/testbench/cpu/decoder_tb.sv

run_test "CPU CORE TEST" cpu_core_tb cpu_core_sim cpu_core.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/alu/arithmetic.sv \
    rtl/cpu/alu/logic_unit.sv \
    rtl/cpu/alu/shifter.sv \
    rtl/cpu/alu/comparator.sv \
    rtl/cpu/alu/alu.sv \
    rtl/cpu/core/register_file.sv \
    rtl/cpu/core/status_register.sv \
    rtl/cpu/core/datapath.sv \
    rtl/cpu/core/decoder.sv \
    rtl/cpu/core/branch_unit.sv \
    rtl/cpu/core/cpu_core.sv \
    sim/testbench/cpu/cpu_core_tb.sv

run_test "PROGRAM COUNTER TEST" program_counter_tb program_counter_sim program_counter.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/fetch/program_counter.sv \
    sim/testbench/cpu/program_counter_tb.sv

run_test "BRANCH UNIT TEST" branch_unit_tb branch_unit_sim branch_unit.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/core/branch_unit.sv \
    sim/testbench/cpu/branch_unit_tb.sv

run_test "INSTRUCTION FETCH / I-BUS TEST" instruction_fetch_tb instruction_fetch_sim instruction_fetch.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/fetch/program_counter.sv \
    rtl/cpu/fetch/instruction_fetch.sv \
    sim/testbench/cpu/instruction_fetch_tb.sv

run_test "DATA MEMORY BUS TEST" data_memory_tb data_memory_sim data_memory.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/memory/data_memory.sv \
    sim/testbench/memory/data_memory_tb.sv

run_test "BUS INTERCONNECT TEST" bus_interconnect_tb bus_interconnect_sim bus_interconnect.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/packages/bus_pkg.sv \
    rtl/bus/address_decoder.sv \
    rtl/bus/bus_interconnect.sv \
    sim/testbench/bus/bus_interconnect_tb.sv

run_test "FINAL CPU I-BUS / D-BUS TEST" cpu_tb cpu_sim cpu.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/cpu/alu/arithmetic.sv \
    rtl/cpu/alu/logic_unit.sv \
    rtl/cpu/alu/shifter.sv \
    rtl/cpu/alu/comparator.sv \
    rtl/cpu/alu/alu.sv \
    rtl/cpu/core/register_file.sv \
    rtl/cpu/core/status_register.sv \
    rtl/cpu/core/datapath.sv \
    rtl/cpu/core/decoder.sv \
    rtl/cpu/core/branch_unit.sv \
    rtl/cpu/core/cpu_core.sv \
    rtl/cpu/fetch/program_counter.sv \
    rtl/cpu/fetch/instruction_fetch.sv \
    rtl/cpu/cpu.sv \
    sim/testbench/cpu/cpu_tb.sv

run_test "CPU SYSTEM TEST" cpu_system_tb cpu_system_sim cpu_system.vcd \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/packages/bus_pkg.sv \
    rtl/cpu/alu/arithmetic.sv \
    rtl/cpu/alu/logic_unit.sv \
    rtl/cpu/alu/shifter.sv \
    rtl/cpu/alu/comparator.sv \
    rtl/cpu/alu/alu.sv \
    rtl/cpu/core/register_file.sv \
    rtl/cpu/core/status_register.sv \
    rtl/cpu/core/datapath.sv \
    rtl/cpu/core/decoder.sv \
    rtl/cpu/core/branch_unit.sv \
    rtl/cpu/core/cpu_core.sv \
    rtl/cpu/fetch/program_counter.sv \
    rtl/cpu/fetch/instruction_fetch.sv \
    rtl/cpu/cpu.sv \
    rtl/bus/address_decoder.sv \
    rtl/bus/bus_interconnect.sv \
    rtl/memory/instruction_memory.sv \
    rtl/memory/data_memory.sv \
    rtl/soc/cpu_system.sv \
    sim/testbench/soc/cpu_system_tb.sv


echo "========== ALL TESTS PASSED =========="

# Use --no-gui for regression only.
if [[ "${1:-}" == "--no-gui" ]]; then
    exit 0
fi

unset GTK_PATH GIO_MODULE_DIR LD_LIBRARY_PATH LD_PRELOAD

gtkwave \
    sim/waveforms/alu.vcd \
    sim/waveforms/register_file.vcd \
    sim/waveforms/datapath.vcd \
    sim/waveforms/decoder_tb.vcd \
    sim/waveforms/cpu_core.vcd \
    sim/waveforms/program_counter.vcd \
    sim/waveforms/branch_unit.vcd \
    sim/waveforms/instruction_fetch.vcd \
    sim/waveforms/data_memory.vcd \
    sim/waveforms/bus_interconnect.vcd \
    sim/waveforms/cpu.vcd \
    sim/waveforms/cpu_system.vcd
