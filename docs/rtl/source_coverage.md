# Source coverage manifest

Every non-testbench RTL source file, the definitions it contains,
the graph that represents it, and the coverage status.

Status: **FULL** = every significant construct represented;
**PARTIAL** = some constructs intentionally omitted (explained);
**EXCLUDED** = not represented (reason given);
**UNRESOLVED** = representation could not be confirmed.

| Source | Definition(s) | Source lines | Graph | Elements | Coverage |
|---|---|---:|---|---:|---|
| rtl/bus/address_decoder.sv | module address_decoder | 11-22 | lacooda.mmd | 4 | FULL |
| rtl/bus/bus_interconnect.sv | module bus_interconnect | 18-53 | lacooda.mmd | 6 | FULL |
| rtl/cpu/alu/alu.sv | module alu | 22-165 | lacooda.mmd | 20 | FULL |
| rtl/cpu/alu/arithmetic.sv | module arithmetic | 18-167 | lacooda.mmd | 17 | FULL |
| rtl/cpu/alu/comparator.sv | module comparator | 11-63 | lacooda.mmd | 5 | FULL |
| rtl/cpu/alu/logic_unit.sv | module logic_unit | 10-37 | lacooda.mmd | 5 | FULL |
| rtl/cpu/alu/shifter.sv | module shifter | 10-54 | lacooda.mmd | 8 | FULL |
| rtl/cpu/core/branch_unit.sv | module branch_unit | 20-54 | lacooda.mmd | 8 | FULL |
| rtl/cpu/core/cpu_core.sv | module cpu_core | 20-228 | lacooda.mmd | 29 | FULL |
| rtl/cpu/core/datapath.sv | module datapath | 25-144 | lacooda.mmd | 19 | FULL |
| rtl/cpu/core/decoder.sv | module decoder | 20-238 | lacooda.mmd | 17 | FULL |
| rtl/cpu/core/register_file.sv | module register_file | 12-38 | lacooda.mmd | 10 | FULL |
| rtl/cpu/core/status_register.sv | module status_register | 14-39 | lacooda.mmd | 7 | FULL |
| rtl/cpu/cpu.sv | module cpu | 26-145 | lacooda.mmd | 16 | FULL |
| rtl/cpu/fetch/instruction_fetch.sv | module instruction_fetch | 28-120 | lacooda.mmd | 18 | FULL |
| rtl/cpu/fetch/program_counter.sv | module program_counter | 8-34 | lacooda.mmd | 5 | FULL |
| rtl/memory/data_memory.sv | module data_memory | 26-69 | lacooda.mmd | 11 | FULL |
| rtl/memory/instruction_memory.sv | module instruction_memory | 22-53 | lacooda.mmd | 9 | FULL |
| rtl/packages/bus_pkg.sv | package bus_pkg | 13-49 | lacooda.mmd | 7 | FULL |
| rtl/packages/cpu_pkg.sv | package cpu_pkg | 24-257 | lacooda.mmd | 34 | FULL |
| rtl/packages/opcode_pkg.sv | package opcode_pkg | 22-133 | lacooda.mmd | 13 | FULL |
| rtl/soc/cpu_system.sv | module cpu_system | 16-75 | lacooda.mmd | 10 | FULL |

## Excluded from diagrams

| Source | Definition | Lines | Graph | Elements | Status | Reason |
|---|---|---:|---|---:|---|---|
| sim/testbench/**/*.sv | 12 testbench modules | all | none | 0 | EXCLUDED | testbench-only, not part of the synthesizable RTL |
| programs/*.hex | program images | all | none | 0 | EXCLUDED | data, referenced from cpu_pkg::PROGRAM_FILE |
| README.md, docs/ | documentation | all | none | 0 | EXCLUDED | non-RTL |
