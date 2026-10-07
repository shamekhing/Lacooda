#!/bin/bash
# LACOODA regression runner.
# Run from the repository root so source paths and ROM initialization resolve.
#
# Word-width selection (see cpu_pkg.sv):
#   ./run.sh              global word = 32 (cpu_pkg default)
#   ./run.sh --word32     global word = 32  (-DLACOODA_WORD_WIDTH=32)
#   ./run.sh --both       run the full regression at 32 and at 64
set -e

WORD_FLAGS=""
NO_GUI=0
for arg in "$@"; do
    if [[ "$arg" == "--word32" ]]; then
        WORD_FLAGS="-DLACOODA_WORD_WIDTH=32"
    elif [[ "$arg" == "--no-gui" ]]; then
        NO_GUI=1
    fi
done

if [[ "${1:-}" == "--both" ]]; then
    "$0" --no-gui
    "$0" --no-gui --word32
    exit 0
fi

mkdir -p src/sim/build src/sim/waveforms

run_test() {
    local label="$1"
    local top="$2"
    local binary="$3"
    local vcd="$4"
    shift 4

    echo "========== ${label} =========="

    # shellcheck disable=SC2086
    iverilog -g2012 -Wall $WORD_FLAGS \
        -s "$top" \
        -o "src/sim/build/$binary" \
        "$@"

    vvp "src/sim/build/$binary"

    if [[ -f "$vcd" ]]; then
        mv -f "$vcd" "src/sim/waveforms/$vcd"
    fi
}

run_test "ALU TEST" alu_tb alu_sim alu.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/alu/arithmetic.sv \
    src/rtl/cpu/alu/logic_unit.sv \
    src/rtl/cpu/alu/shifter.sv \
    src/rtl/cpu/alu/comparator.sv \
    src/rtl/cpu/alu/alu.sv \
    src/rtl/cpu/core/status_register.sv \
    src/sim/testbench/cpu/alu_tb.sv

run_test "REGISTER FILE TEST" cpu_register_tb cpu_register_sim cpu_register.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/core/cpu_register.sv \
    src/sim/testbench/cpu/cpu_register_tb.sv

run_test "cpu_datapath TEST" cpu_datapath_tb cpu_datapath_sim cpu_datapath.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/alu/arithmetic.sv \
    src/rtl/cpu/alu/logic_unit.sv \
    src/rtl/cpu/alu/shifter.sv \
    src/rtl/cpu/alu/comparator.sv \
    src/rtl/cpu/alu/alu.sv \
    src/rtl/cpu/core/cpu_register.sv \
    src/rtl/cpu/core/status_register.sv \
    src/rtl/cpu/core/cpu_datapath.sv \
    src/sim/testbench/cpu/cpu_datapath_tb.sv

run_test "cpu_decoder TEST" cpu_decoder_tb cpu_decoder_sim cpu_decoder_tb.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/core/cpu_decoder.sv \
    src/sim/testbench/cpu/cpu_decoder_tb.sv

run_test "CPU CORE TEST" cpu_core_tb cpu_core_sim cpu_core.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/alu/arithmetic.sv \
    src/rtl/cpu/alu/logic_unit.sv \
    src/rtl/cpu/alu/shifter.sv \
    src/rtl/cpu/alu/comparator.sv \
    src/rtl/cpu/alu/alu.sv \
    src/rtl/cpu/core/cpu_register.sv \
    src/rtl/cpu/core/status_register.sv \
    src/rtl/cpu/core/cpu_datapath.sv \
    src/rtl/cpu/core/cpu_decoder.sv \
    src/rtl/cpu/core/branch_unit.sv \
    src/rtl/cpu/core/cpu_core.sv \
    src/sim/testbench/cpu/cpu_core_tb.sv

run_test "PROGRAM COUNTER TEST" program_counter_tb program_counter_sim program_counter.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/fetch/program_counter.sv \
    src/sim/testbench/cpu/program_counter_tb.sv

run_test "BRANCH UNIT TEST" branch_unit_tb branch_unit_sim branch_unit.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/core/branch_unit.sv \
    src/sim/testbench/cpu/branch_unit_tb.sv

run_test "INSTRUCTION FETCH / I-BUS TEST" instruction_fetch_tb instruction_fetch_sim instruction_fetch.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/fetch/program_counter.sv \
    src/rtl/cpu/fetch/instruction_fetch.sv \
    src/sim/testbench/cpu/instruction_fetch_tb.sv

run_test "DATA MEMORY BUS TEST" data_memory_tb data_memory_sim data_memory.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/memory/data_memory.sv \
    src/sim/testbench/memory/data_memory_tb.sv

run_test "BUS INTERCONNECT TEST" bus_interconnect_tb bus_interconnect_sim bus_interconnect.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/bus/address_cpu_decoder.sv \
    src/rtl/bus/bus_interconnect.sv \
    src/sim/testbench/bus/bus_interconnect_tb.sv

run_test "FINAL CPU I-BUS / D-BUS TEST" cpu_tb cpu_sim cpu.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/alu/arithmetic.sv \
    src/rtl/cpu/alu/logic_unit.sv \
    src/rtl/cpu/alu/shifter.sv \
    src/rtl/cpu/alu/comparator.sv \
    src/rtl/cpu/alu/alu.sv \
    src/rtl/cpu/core/cpu_register.sv \
    src/rtl/cpu/core/status_register.sv \
    src/rtl/cpu/core/cpu_datapath.sv \
    src/rtl/cpu/core/cpu_decoder.sv \
    src/rtl/cpu/core/branch_unit.sv \
    src/rtl/cpu/core/cpu_core.sv \
    src/rtl/cpu/fetch/program_counter.sv \
    src/rtl/cpu/fetch/instruction_fetch.sv \
    src/rtl/cpu/cpu.sv \
    src/sim/testbench/cpu/cpu_tb.sv

run_test "CPU SYSTEM TEST" system_tb system_sim system.vcd \
    src/rtl/packages/opcode_pkg.sv \
    src/rtl/packages/cpu_pkg.sv \
    src/rtl/packages/alu_pkg.sv \
    src/rtl/packages/bus_pkg.sv \
    src/rtl/cpu/alu/arithmetic.sv \
    src/rtl/cpu/alu/logic_unit.sv \
    src/rtl/cpu/alu/shifter.sv \
    src/rtl/cpu/alu/comparator.sv \
    src/rtl/cpu/alu/alu.sv \
    src/rtl/cpu/core/cpu_register.sv \
    src/rtl/cpu/core/status_register.sv \
    src/rtl/cpu/core/cpu_datapath.sv \
    src/rtl/cpu/core/cpu_decoder.sv \
    src/rtl/cpu/core/branch_unit.sv \
    src/rtl/cpu/core/cpu_core.sv \
    src/rtl/cpu/fetch/program_counter.sv \
    src/rtl/cpu/fetch/instruction_fetch.sv \
    src/rtl/cpu/cpu.sv \
    src/rtl/bus/address_cpu_decoder.sv \
    src/rtl/bus/bus_interconnect.sv \
    src/rtl/memory/instruction_memory.sv \
    src/rtl/memory/data_memory.sv \
    src/rtl/soc/system.sv \
    src/sim/testbench/soc/system_tb.sv


echo "========== ALL TESTS PASSED =========="

# Use --no-gui for regression only.
if [[ "$NO_GUI" == "1" ]]; then
    exit 0
fi

unset GTK_PATH GIO_MODULE_DIR LD_LIBRARY_PATH LD_PRELOAD

gtkwave \
    src/sim/waveforms/alu.vcd \
    src/sim/waveforms/cpu_register.vcd \
    src/sim/waveforms/cpu_datapath.vcd \
    src/sim/waveforms/cpu_decoder_tb.vcd \
    src/sim/waveforms/cpu_core.vcd \
    src/sim/waveforms/program_counter.vcd \
    src/sim/waveforms/branch_unit.vcd \
    src/sim/waveforms/instruction_fetch.vcd \
    src/sim/waveforms/data_memory.vcd \
    src/sim/waveforms/bus_interconnect.vcd \
    src/sim/waveforms/cpu.vcd \
    src/sim/waveforms/system.vcd
