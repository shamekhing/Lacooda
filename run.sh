
#!/bin/bash
set -e

mkdir -p sim/build sim/waveforms

# ============================================================
# 1. ALU
# ============================================================

echo "========== ALU TEST =========="

iverilog -g2012 -Wall \
    -s alu_tb \
    -o sim/build/alu_sim \
    rtl/packages/opcode_pkg.sv \
    rtl/packages/flags_pkg.sv \
    rtl/alu/arithmetic.sv \
    rtl/alu/logic_unit.sv \
    rtl/alu/shifter.sv \
    rtl/alu/comparator.sv \
    rtl/alu/alu.sv \
    rtl/core/status_register.sv \
    sim/testbench/alu_tb.sv

vvp sim/build/alu_sim
mv -f alu.vcd sim/waveforms/alu.vcd

# ============================================================
# 2. REGISTER FILE
# ============================================================

echo "========== REGISTER FILE TEST =========="

iverilog -g2012 -Wall \
    -s register_file_tb \
    -o sim/build/register_file_sim \
    rtl/core/register_file.sv \
    sim/testbench/register_file_tb.sv

vvp sim/build/register_file_sim
mv -f register_file.vcd sim/waveforms/register_file.vcd

# ============================================================
# 3. WAVEFORMS
# ============================================================

echo "========== ALL TESTS PASSED =========="

# Clear conflicting Snap libraries
unset GTK_PATH GIO_MODULE_DIR LD_LIBRARY_PATH LD_PRELOAD

# Open both waveform files
gtkwave \
    sim/waveforms/alu.vcd \
    sim/waveforms/register_file.vcd
