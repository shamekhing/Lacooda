
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
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
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
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/core/register_file.sv \
    sim/testbench/register_file_tb.sv

vvp sim/build/register_file_sim
mv -f register_file.vcd sim/waveforms/register_file.vcd

# ============================================================
# 3. DATAPATH
# ============================================================

echo "========== DATAPATH TEST =========="

iverilog -g2012 -Wall \
    -s datapath_tb \
    -o sim/build/datapath_sim \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/alu/arithmetic.sv \
    rtl/alu/logic_unit.sv \
    rtl/alu/shifter.sv \
    rtl/alu/comparator.sv \
    rtl/alu/alu.sv \
    rtl/core/register_file.sv \
    rtl/core/status_register.sv \
    rtl/core/datapath.sv \
    sim/testbench/datapath_tb.sv

vvp sim/build/datapath_sim

mv -f datapath.vcd sim/waveforms/datapath.vcd


# ============================================================
# 4. DECODER
# ============================================================

echo "========== DECODER TEST =========="

iverilog -g2012 -Wall \
    -s decoder_tb \
    -o sim/build/decoder_sim \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/core/decoder.sv \
    sim/testbench/decoder_tb.sv

vvp sim/build/decoder_sim
mv -f decoder_tb.vcd sim/waveforms/decoder_tb.vcd


# ============================================================
# 5. CPU CORE INTEGRATION
# ============================================================

echo "========== CPU CORE TEST =========="

iverilog -g2012 -Wall \
    -s cpu_core_tb \
    -o sim/build/cpu_core_sim \
    rtl/packages/alu_pkg.sv \
    rtl/packages/cpu_pkg.sv \
    rtl/alu/arithmetic.sv \
    rtl/alu/logic_unit.sv \
    rtl/alu/shifter.sv \
    rtl/alu/comparator.sv \
    rtl/alu/alu.sv \
    rtl/core/register_file.sv \
    rtl/core/status_register.sv \
    rtl/core/datapath.sv \
    rtl/core/decoder.sv \
    rtl/core/cpu_core.sv \
    sim/testbench/cpu_core_tb.sv

vvp sim/build/cpu_core_sim

mv -f cpu_core.vcd sim/waveforms/cpu_core.vcd


# ============================================================
# WAVEFORMS
# ============================================================

echo "========== ALL TESTS PASSED =========="

if [[ "${1:-}" == "--no-gui" ]]; then
    exit 0
fi

# Clear conflicting Snap libraries
unset GTK_PATH GIO_MODULE_DIR LD_LIBRARY_PATH LD_PRELOAD

# Open waveforms files
gtkwave \
    sim/waveforms/alu.vcd \
    sim/waveforms/register_file.vcd \
    sim/waveforms/datapath.vcd \
    sim/waveforms/decoder_tb.vcd \
    sim/waveforms/cpu_core.vcd

