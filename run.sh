
#!/bin/bash
set -e

iverilog -g2012 -Wall \
    -s alu_tb \
    -o alu_sim \
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
mv alu.vcd sim/waveforms/alu.vcd

# Clear conflicting Snap libraries
unset GTK_PATH GIO_MODULE_DIR LD_LIBRARY_PATH LD_PRELOAD
gtkwave alu.vcd