# RTL → Graph index

Reverse index: given a construct in the RTL source, find its graph element.

All elements live in `docs/rtl/lacooda.mmd` unless noted.
Sources are relative to the repository root. Line ranges were read from the
current files and are stable as long as the RTL is not modified.

---

## rtl/packages/opcode_pkg.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/packages/opcode_pkg.sv | 22-133 | package opcode_pkg | lacooda.mmd | pkg_opcode |
| rtl/packages/opcode_pkg.sv | 26 | localparam OPCODE_WIDTH | lacooda.mmd | pkg_opcode_pkg_param_OPCODE_WIDTH |
| rtl/packages/opcode_pkg.sv | 28-88 | typedef enum opcode_e (ALU_/CTRL_/MEM_ codepoints) | lacooda.mmd | pkg_opcode_pkg_enum_opcode_e |
| rtl/packages/opcode_pkg.sv | 91 | typedef opcode_t | lacooda.mmd | pkg_opcode_pkg_type_opcode_t |
| rtl/packages/opcode_pkg.sv | 94 | localparam ALU_OPCODE_COUNT | lacooda.mmd | pkg_opcode_pkg_param_ALU_OPCODE_COUNT |
| rtl/packages/opcode_pkg.sv | 97 | localparam OPCODE_COUNT | lacooda.mmd | pkg_opcode_pkg_param_OPCODE_COUNT |
| rtl/packages/opcode_pkg.sv | 105-107 | function is_valid_opcode | lacooda.mmd | pkg_opcode_pkg_func_is_valid_opcode |
| rtl/packages/opcode_pkg.sv | 109-111 | function is_alu_opcode | lacooda.mmd | pkg_opcode_pkg_func_is_alu_opcode |
| rtl/packages/opcode_pkg.sv | 113-115 | function is_unary_opcode | lacooda.mmd | pkg_opcode_pkg_func_is_unary_opcode |
| rtl/packages/opcode_pkg.sv | 117-119 | function is_mov_op | lacooda.mmd | pkg_opcode_pkg_func_is_mov_op |
| rtl/packages/opcode_pkg.sv | 121-123 | function is_movi_op | lacooda.mmd | pkg_opcode_pkg_func_is_movi_op |
| rtl/packages/opcode_pkg.sv | 125-127 | function is_branch_opcode | lacooda.mmd | pkg_opcode_pkg_func_is_branch_opcode |
| rtl/packages/opcode_pkg.sv | 129-131 | function is_memory_opcode | lacooda.mmd | pkg_opcode_pkg_func_is_memory_opcode |

## rtl/packages/cpu_pkg.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/packages/cpu_pkg.sv | 24-257 | package cpu_pkg | lacooda.mmd | pkg_cpu |
| rtl/packages/cpu_pkg.sv | 35-37 | macro LACOODA_WORD_WIDTH (default 64) | lacooda.mmd | pkg_cpu_pkg_macro_LACOODA_WORD_WIDTH |
| rtl/packages/cpu_pkg.sv | 39 | localparam WORD_WIDTH | lacooda.mmd | pkg_cpu_pkg_param_WORD_WIDTH |
| rtl/packages/cpu_pkg.sv | 40 | localparam WORD_BYTES | lacooda.mmd | pkg_cpu_pkg_param_WORD_BYTES |
| rtl/packages/cpu_pkg.sv | 48 | typedef word_t | lacooda.mmd | pkg_cpu_pkg_type_word_t |
| rtl/packages/cpu_pkg.sv | 51 | typedef instruction_t | lacooda.mmd | pkg_cpu_pkg_type_instruction_t |
| rtl/packages/cpu_pkg.sv | 57 | localparam REG_FILE_COUNT | lacooda.mmd | pkg_cpu_pkg_param_REG_FILE_COUNT |
| rtl/packages/cpu_pkg.sv | 58 | localparam REG_FILE_ADDR_WIDTH | lacooda.mmd | pkg_cpu_pkg_param_REG_FILE_ADDR_WIDTH |
| rtl/packages/cpu_pkg.sv | 60 | typedef reg_addr_t | lacooda.mmd | pkg_cpu_pkg_type_reg_addr_t |
| rtl/packages/cpu_pkg.sv | 63 | localparam ZERO_REG | lacooda.mmd | pkg_cpu_pkg_param_ZERO_REG |
| rtl/packages/cpu_pkg.sv | 69 | localparam INSTRUCTION_MEMORY_COUNT | lacooda.mmd | pkg_cpu_pkg_param_INSTRUCTION_MEMORY_COUNT |
| rtl/packages/cpu_pkg.sv | 70 | localparam DATA_MEMORY_COUNT | lacooda.mmd | pkg_cpu_pkg_param_DATA_MEMORY_COUNT |
| rtl/packages/cpu_pkg.sv | 73-74 | localparam PROGRAM_FILE (word-width dependent) | lacooda.mmd | pkg_cpu_pkg_param_PROGRAM_FILE |
| rtl/packages/cpu_pkg.sv | 83 | localparam STATUS_WIDTH = 32 | lacooda.mmd | pkg_cpu_pkg_param_STATUS_WIDTH |
| rtl/packages/cpu_pkg.sv | 85 | typedef status_t | lacooda.mmd | pkg_cpu_pkg_type_status_t |
| rtl/packages/cpu_pkg.sv | 93-99 | typedef struct flags_t (Z N C V DZ) | lacooda.mmd | pkg_cpu_pkg_type_flags_t |
| rtl/packages/cpu_pkg.sv | 101-111 | function make_flags | lacooda.mmd | pkg_cpu_pkg_func_make_flags |
| rtl/packages/cpu_pkg.sv | 119-120 | localparam RS2_LSB / RS2_MSB | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 121-122 | localparam RS1_LSB / RS1_MSB | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 123-124 | localparam RD_LSB / RD_MSB | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 125-126 | localparam OPCODE_LSB / OPCODE_MSB | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 127 | localparam IMM_MODE_BIT | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 128 | localparam UPDATE_STATUS_BIT | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 129-130 | localparam RESERVED_LSB / RESERVED_MSB | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 131-132 | localparam USED_INSTRUCTION_BITS / RESERVED_WIDTH | lacooda.mmd | pkg_cpu_pkg_param_LAYOUT |
| rtl/packages/cpu_pkg.sv | 135-156 | function validate_configuration | lacooda.mmd | pkg_cpu_pkg_func_validate_configuration |
| rtl/packages/cpu_pkg.sv | 160-167 | typedef struct instr_fields_t | lacooda.mmd | pkg_cpu_pkg_type_instr_fields_t |
| rtl/packages/cpu_pkg.sv | 178-183 | function uses_imm | lacooda.mmd | pkg_cpu_pkg_func_uses_imm |
| rtl/packages/cpu_pkg.sv | 185-189 | function instr_uses_imm | lacooda.mmd | pkg_cpu_pkg_func_instr_uses_imm |
| rtl/packages/cpu_pkg.sv | 193-207 | function encode_instruction | lacooda.mmd | pkg_cpu_pkg_func_encode_instruction |
| rtl/packages/cpu_pkg.sv | 211-222 | function encode_branch | lacooda.mmd | pkg_cpu_pkg_func_encode_branch |
| rtl/packages/cpu_pkg.sv | 225-227 | function encode_jump | lacooda.mmd | pkg_cpu_pkg_func_encode_jump |
| rtl/packages/cpu_pkg.sv | 231-241 | function encode_load | lacooda.mmd | pkg_cpu_pkg_func_encode_load |
| rtl/packages/cpu_pkg.sv | 245-255 | function encode_store | lacooda.mmd | pkg_cpu_pkg_func_encode_store |

## rtl/packages/bus_pkg.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/packages/bus_pkg.sv | 13-49 | package bus_pkg | lacooda.mmd | pkg_bus |
| rtl/packages/bus_pkg.sv | 15-18 | typedef enum bus_op_t (BUS_READ/BUS_WRITE) | lacooda.mmd | pkg_bus_pkg_enum_bus_op_t |
| rtl/packages/bus_pkg.sv | 21-26 | typedef struct bus_req_t (valid op addr wdata) | lacooda.mmd | pkg_bus_pkg_struct_bus_req_t |
| rtl/packages/bus_pkg.sv | 28-31 | typedef struct bus_rsp_t (ready rdata) | lacooda.mmd | pkg_bus_pkg_struct_bus_rsp_t |
| rtl/packages/bus_pkg.sv | 36 | localparam DATA_MEMORY_BASE | lacooda.mmd | pkg_bus_pkg_param_DATA_MEMORY_BASE |
| rtl/packages/bus_pkg.sv | 42-44 | localparam DATA_MEMORY_SIZE | lacooda.mmd | pkg_bus_pkg_param_DATA_MEMORY_SIZE |
| rtl/packages/bus_pkg.sv | 46-47 | localparam DATA_MEMORY_LIMIT | lacooda.mmd | pkg_bus_pkg_param_DATA_MEMORY_LIMIT |

## rtl/cpu/alu/alu.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/alu/alu.sv | 22-165 | module alu | lacooda.mmd | mod_alu |
| rtl/cpu/alu/alu.sv | 23 | input operand_a | lacooda.mmd | mod_alu_port_operand_a |
| rtl/cpu/alu/alu.sv | 23 | input operand_b | lacooda.mmd | mod_alu_port_operand_b |
| rtl/cpu/alu/alu.sv | 24 | input op : opcode_t | lacooda.mmd | mod_alu_port_op |
| rtl/cpu/alu/alu.sv | 25 | input carry_in | lacooda.mmd | mod_alu_port_carry_in |
| rtl/cpu/alu/alu.sv | 27 | output result : word_t | lacooda.mmd | mod_alu_port_result |
| rtl/cpu/alu/alu.sv | 28 | output flags : flags_t | lacooda.mmd | mod_alu_port_flags |
| rtl/cpu/alu/alu.sv | 29 | output valid | lacooda.mmd | mod_alu_port_valid |
| rtl/cpu/alu/alu.sv | 36 | signal arithmetic_result | lacooda.mmd | mod_alu_sig_arithmetic_result |
| rtl/cpu/alu/alu.sv | 37 | signal logic_result | lacooda.mmd | mod_alu_sig_logic_result |
| rtl/cpu/alu/alu.sv | 38 | signal shift_result | lacooda.mmd | mod_alu_sig_shift_result |
| rtl/cpu/alu/alu.sv | 39 | signal compare_result | lacooda.mmd | mod_alu_sig_compare_result |
| rtl/cpu/alu/alu.sv | 42-44 | signals arithmetic_carry/overflow/div_zero | lacooda.mmd | mod_alu_sig_arithmetic_carry |
| rtl/cpu/alu/alu.sv | 47-49 | signals carry_sel/overflow_sel/div_zero_sel | lacooda.mmd | mod_alu_sig_carry_sel |
| rtl/cpu/alu/alu.sv | 52-61 | instance u_arithmetic | lacooda.mmd | mod_alu_inst_arithmetic |
| rtl/cpu/alu/alu.sv | 64-69 | instance u_logic_unit | lacooda.mmd | mod_alu_inst_logic_unit |
| rtl/cpu/alu/alu.sv | 72-77 | instance u_shifter | lacooda.mmd | mod_alu_inst_shifter |
| rtl/cpu/alu/alu.sv | 80-85 | instance u_comparator | lacooda.mmd | mod_alu_inst_comparator |
| rtl/cpu/alu/alu.sv | 88-149 | always_comb result multiplexer | lacooda.mmd | mod_alu_comb_L88 |
| rtl/cpu/alu/alu.sv | 152-163 | always_comb flags derivation | lacooda.mmd | mod_alu_comb_L152 |

## rtl/cpu/alu/arithmetic.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/alu/arithmetic.sv | 18-167 | module arithmetic | lacooda.mmd | mod_arithmetic |
| rtl/cpu/alu/arithmetic.sv | 19 | input operand_a / operand_b | lacooda.mmd | mod_arithmetic_port_operand_a |
| rtl/cpu/alu/arithmetic.sv | 20 | input op | lacooda.mmd | mod_arithmetic_port_op |
| rtl/cpu/alu/arithmetic.sv | 21 | input carry_in | lacooda.mmd | mod_arithmetic_port_carry_in |
| rtl/cpu/alu/arithmetic.sv | 23 | output result | lacooda.mmd | mod_arithmetic_port_result |
| rtl/cpu/alu/arithmetic.sv | 24 | output carry | lacooda.mmd | mod_arithmetic_port_carry |
| rtl/cpu/alu/arithmetic.sv | 25 | output overflow | lacooda.mmd | mod_arithmetic_port_overflow |
| rtl/cpu/alu/arithmetic.sv | 26 | output div_zero | lacooda.mmd | mod_arithmetic_port_div_zero |
| rtl/cpu/alu/arithmetic.sv | 32 | signal add_ext | lacooda.mmd | mod_arithmetic_sig_add_ext |
| rtl/cpu/alu/arithmetic.sv | 33 | signal product | lacooda.mmd | mod_arithmetic_sig_product |
| rtl/cpu/alu/arithmetic.sv | 35-36 | signals signed_a / signed_b | lacooda.mmd | mod_arithmetic_sig_signed_a |
| rtl/cpu/alu/arithmetic.sv | 38 | signal min_signed | lacooda.mmd | mod_arithmetic_sig_min_signed |
| rtl/cpu/alu/arithmetic.sv | 40 | signal rhs | lacooda.mmd | mod_arithmetic_sig_rhs |
| rtl/cpu/alu/arithmetic.sv | 42 | assign signed_a | lacooda.mmd | mod_arithmetic_assign_L42 |
| rtl/cpu/alu/arithmetic.sv | 43 | assign signed_b | lacooda.mmd | mod_arithmetic_assign_L43 |
| rtl/cpu/alu/arithmetic.sv | 45 | assign min_signed | lacooda.mmd | mod_arithmetic_assign_L45 |
| rtl/cpu/alu/arithmetic.sv | 47-165 | always_comb arithmetic | lacooda.mmd | mod_arithmetic_comb_L47 |

## rtl/cpu/alu/comparator.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/alu/comparator.sv | 11-63 | module comparator | lacooda.mmd | mod_comparator |
| rtl/cpu/alu/comparator.sv | 12 | input operand_a / operand_b | lacooda.mmd | mod_comparator_port_operand_a |
| rtl/cpu/alu/comparator.sv | 13 | input op | lacooda.mmd | mod_comparator_port_op |
| rtl/cpu/alu/comparator.sv | 15 | output result | lacooda.mmd | mod_comparator_port_result |
| rtl/cpu/alu/comparator.sv | 20-61 | always_comb comparisons | lacooda.mmd | mod_comparator_comb_L20 |

## rtl/cpu/alu/logic_unit.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/alu/logic_unit.sv | 10-37 | module logic_unit | lacooda.mmd | mod_logic_unit |
| rtl/cpu/alu/logic_unit.sv | 11 | input operand_a / operand_b | lacooda.mmd | mod_logic_unit_port_operand_a |
| rtl/cpu/alu/logic_unit.sv | 12 | input op | lacooda.mmd | mod_logic_unit_port_op |
| rtl/cpu/alu/logic_unit.sv | 14 | output result | lacooda.mmd | mod_logic_unit_port_result |
| rtl/cpu/alu/logic_unit.sv | 19-35 | always_comb bitwise ops | lacooda.mmd | mod_logic_unit_comb_L19 |

## rtl/cpu/alu/shifter.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/alu/shifter.sv | 10-54 | module shifter | lacooda.mmd | mod_shifter |
| rtl/cpu/alu/shifter.sv | 11 | input operand_a / operand_b | lacooda.mmd | mod_shifter_port_operand_a |
| rtl/cpu/alu/shifter.sv | 12 | input op | lacooda.mmd | mod_shifter_port_op |
| rtl/cpu/alu/shifter.sv | 14 | output result | lacooda.mmd | mod_shifter_port_result |
| rtl/cpu/alu/shifter.sv | 19 | localparam SHIFT_WIDTH | lacooda.mmd | mod_shifter_param_SHIFT_WIDTH |
| rtl/cpu/alu/shifter.sv | 21 | signal shift_amount | lacooda.mmd | mod_shifter_sig_shift_amount |
| rtl/cpu/alu/shifter.sv | 24 | assign shift_amount | lacooda.mmd | mod_shifter_assign_L24 |
| rtl/cpu/alu/shifter.sv | 26-52 | always_comb shifts/rotates | lacooda.mmd | mod_shifter_comb_L26 |

## rtl/cpu/core/register_file.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/core/register_file.sv | 12-38 | module register_file | lacooda.mmd | mod_register_file |
| rtl/cpu/core/register_file.sv | 13-14 | input clk / rst | lacooda.mmd | mod_register_file_port_clk |
| rtl/cpu/core/register_file.sv | 15-16 | rs1_addr / rs1_data | lacooda.mmd | mod_register_file_port_rs1_addr |
| rtl/cpu/core/register_file.sv | 17-18 | rs2_addr / rs2_data | lacooda.mmd | mod_register_file_port_rs2_addr |
| rtl/cpu/core/register_file.sv | 19-21 | write_enable / write_addr / write_data | lacooda.mmd | mod_register_file_port_write_enable |
| rtl/cpu/core/register_file.sv | 23 | memory registers [0:REG_FILE_COUNT-1] | lacooda.mmd | mod_register_file_mem_registers |
| rtl/cpu/core/register_file.sv | 26 | assign rs1_data (R0 reads 0) | lacooda.mmd | mod_register_file_assign_L26 |
| rtl/cpu/core/register_file.sv | 27 | assign rs2_data (R0 reads 0) | lacooda.mmd | mod_register_file_assign_L27 |
| rtl/cpu/core/register_file.sv | 29 | integer idx | lacooda.mmd | mod_register_file_sig_idx |
| rtl/cpu/core/register_file.sv | 30-37 | always_ff reset clear + write | lacooda.mmd | mod_register_file_ff_L30 |

## rtl/cpu/core/status_register.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/core/status_register.sv | 14-39 | module status_register | lacooda.mmd | mod_status_register |
| rtl/cpu/core/status_register.sv | 15-17 | input clk / rst / write_enable | lacooda.mmd | mod_status_register_port_clk |
| rtl/cpu/core/status_register.sv | 19 | input flags_in | lacooda.mmd | mod_status_register_port_flags_in |
| rtl/cpu/core/status_register.sv | 20 | output status | lacooda.mmd | mod_status_register_port_status |
| rtl/cpu/core/status_register.sv | 23 | signal flags_reg | lacooda.mmd | mod_status_register_sig_flags_reg |
| rtl/cpu/core/status_register.sv | 25-33 | always_ff flag storage | lacooda.mmd | mod_status_register_ff_L25 |
| rtl/cpu/core/status_register.sv | 35-37 | assign status {DZ,V,C,N,Z} | lacooda.mmd | mod_status_register_assign_L35 |

## rtl/cpu/core/branch_unit.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/core/branch_unit.sv | 20-54 | module branch_unit | lacooda.mmd | mod_branch_unit |
| rtl/cpu/core/branch_unit.sv | 21 | input enable | lacooda.mmd | mod_branch_unit_port_enable |
| rtl/cpu/core/branch_unit.sv | 22 | input opcode | lacooda.mmd | mod_branch_unit_port_opcode |
| rtl/cpu/core/branch_unit.sv | 23-24 | input operand_a / operand_b | lacooda.mmd | mod_branch_unit_port_operand_a |
| rtl/cpu/core/branch_unit.sv | 25 | input target | lacooda.mmd | mod_branch_unit_port_target |
| rtl/cpu/core/branch_unit.sv | 27 | output redirect | lacooda.mmd | mod_branch_unit_port_redirect |
| rtl/cpu/core/branch_unit.sv | 28 | output redirect_target | lacooda.mmd | mod_branch_unit_port_redirect_target |
| rtl/cpu/core/branch_unit.sv | 33-52 | always_comb condition select | lacooda.mmd | mod_branch_unit_comb_L33 |

## rtl/cpu/core/decoder.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/core/decoder.sv | 20-238 | module decoder | lacooda.mmd | mod_decoder |
| rtl/cpu/core/decoder.sv | 21 | input instruction | lacooda.mmd | mod_decoder_port_instruction |
| rtl/cpu/core/decoder.sv | 22 | input immediate_word | lacooda.mmd | mod_decoder_port_immediate_word |
| rtl/cpu/core/decoder.sv | 24-26 | outputs rs1 / rs2 / rd | lacooda.mmd | mod_decoder_port_rs1 |
| rtl/cpu/core/decoder.sv | 28-30 | outputs alu_op / imm_operand / imm_sel | lacooda.mmd | mod_decoder_port_alu_op |
| rtl/cpu/core/decoder.sv | 32-33 | outputs register_write_enable / flags_write_enable | lacooda.mmd | mod_decoder_port_register_write_enable |
| rtl/cpu/core/decoder.sv | 36-38 | outputs branch_enable / branch_op / branch_target | lacooda.mmd | mod_decoder_port_branch_enable |
| rtl/cpu/core/decoder.sv | 41-42 | outputs memory_read_enable / memory_write_enable | lacooda.mmd | mod_decoder_port_memory_read_enable |
| rtl/cpu/core/decoder.sv | 44-45 | outputs decode_valid / illegal_instr | lacooda.mmd | mod_decoder_port_decode_valid |
| rtl/cpu/core/decoder.sv | 51 | signal instr_fields | lacooda.mmd | mod_decoder_sig_instr_fields |
| rtl/cpu/core/decoder.sv | 53-54 | signals opcode_valid / format_valid | lacooda.mmd | mod_decoder_sig_opcode_valid |
| rtl/cpu/core/decoder.sv | 55-57 | signals unary_qual / mov_qual / movi_qual | lacooda.mmd | mod_decoder_sig_unary_qual |
| rtl/cpu/core/decoder.sv | 58-59 | signals branch_qual / memory_qual | lacooda.mmd | mod_decoder_sig_branch_qual |
| rtl/cpu/core/decoder.sv | 60-61 | signals load_qual / store_qual | lacooda.mmd | mod_decoder_sig_load_qual |
| rtl/cpu/core/decoder.sv | 67 | assign instr_fields = instruction | lacooda.mmd | mod_decoder_assign_L67 |
| rtl/cpu/core/decoder.sv | 72-158 | always_comb format validation | lacooda.mmd | mod_decoder_comb_L72 |
| rtl/cpu/core/decoder.sv | 163-236 | always_comb control generation | lacooda.mmd | mod_decoder_comb_L163 |

## rtl/cpu/core/datapath.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/core/datapath.sv | 25-144 | module datapath | lacooda.mmd | mod_datapath |
| rtl/cpu/core/datapath.sv | 26-27 | input clk / rst | lacooda.mmd | mod_datapath_port_clk |
| rtl/cpu/core/datapath.sv | 30-32 | inputs rs1 / rs2 / rd | lacooda.mmd | mod_datapath_port_rs1 |
| rtl/cpu/core/datapath.sv | 35-36 | inputs alu_op / carry_in | lacooda.mmd | mod_datapath_port_alu_op |
| rtl/cpu/core/datapath.sv | 39-40 | inputs imm_operand / imm_sel | lacooda.mmd | mod_datapath_port_imm_operand |
| rtl/cpu/core/datapath.sv | 43-44 | inputs register_write_enable / flags_write_enable | lacooda.mmd | mod_datapath_port_register_write_enable |
| rtl/cpu/core/datapath.sv | 47-48 | inputs dmem_rdata / writeback_from_mem | lacooda.mmd | mod_datapath_port_dmem_rdata |
| rtl/cpu/core/datapath.sv | 51-55 | outputs operand_a/operand_b/store_data/alu_result/alu_valid | lacooda.mmd | mod_datapath_port_operand_a |
| rtl/cpu/core/datapath.sv | 58-59 | outputs flags / status | lacooda.mmd | mod_datapath_port_flags |
| rtl/cpu/core/datapath.sv | 61-62 | signals rs2_data / writeback_data | lacooda.mmd | mod_datapath_sig_rs2_data |
| rtl/cpu/core/datapath.sv | 64-65 | signals register_wen / flags_wen | lacooda.mmd | mod_datapath_sig_register_wen |
| rtl/cpu/core/datapath.sv | 71-72 | assign register_wen | lacooda.mmd | mod_datapath_assign_L71 |
| rtl/cpu/core/datapath.sv | 74-75 | assign flags_wen | lacooda.mmd | mod_datapath_assign_L74 |
| rtl/cpu/core/datapath.sv | 81-94 | instance u_register_file | lacooda.mmd | mod_datapath_inst_register_file |
| rtl/cpu/core/datapath.sv | 97 | assign store_data | lacooda.mmd | mod_datapath_assign_L97 |
| rtl/cpu/core/datapath.sv | 103-104 | assign operand_b (imm mux) | lacooda.mmd | mod_datapath_assign_L103 |
| rtl/cpu/core/datapath.sv | 110-120 | instance u_alu | lacooda.mmd | mod_datapath_inst_alu |
| rtl/cpu/core/datapath.sv | 128-129 | assign writeback_data | lacooda.mmd | mod_datapath_assign_L128 |
| rtl/cpu/core/datapath.sv | 135-142 | instance u_status_register | lacooda.mmd | mod_datapath_inst_status_register |

## rtl/cpu/core/cpu_core.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/core/cpu_core.sv | 20-228 | module cpu_core | lacooda.mmd | mod_cpu_core |
| rtl/cpu/core/cpu_core.sv | 21-22 | input clk / rst | lacooda.mmd | mod_cpu_core_port_clk |
| rtl/cpu/core/cpu_core.sv | 24-26 | inputs core_enable / instruction_word / immediate_word | lacooda.mmd | mod_cpu_core_port_core_enable |
| rtl/cpu/core/cpu_core.sv | 29 | input carry_in | lacooda.mmd | mod_cpu_core_port_carry_in |
| rtl/cpu/core/cpu_core.sv | 35-36 | inputs dbus_ready / dbus_rdata | lacooda.mmd | mod_cpu_core_port_dbus_ready |
| rtl/cpu/core/cpu_core.sv | 38-40 | outputs decode_valid / illegal_instr / retire_valid | lacooda.mmd | mod_cpu_core_port_decode_valid |
| rtl/cpu/core/cpu_core.sv | 43-44 | outputs redirect / redirect_target | lacooda.mmd | mod_cpu_core_port_redirect |
| rtl/cpu/core/cpu_core.sv | 54-57 | outputs dbus_valid / dbus_write / dbus_addr / dbus_wdata | lacooda.mmd | mod_cpu_core_port_dbus_valid |
| rtl/cpu/core/cpu_core.sv | 59-61 | outputs operand_a / operand_b / alu_result | lacooda.mmd | mod_cpu_core_port_operand_a |
| rtl/cpu/core/cpu_core.sv | 63-64 | outputs flags / status | lacooda.mmd | mod_cpu_core_port_flags |
| rtl/cpu/core/cpu_core.sv | 67-69 | signals rs1 / rs2 / rd | lacooda.mmd | mod_cpu_core_sig_rs1 |
| rtl/cpu/core/cpu_core.sv | 71-72 | signals alu_op / imm_operand | lacooda.mmd | mod_cpu_core_sig_alu_op |
| rtl/cpu/core/cpu_core.sv | 74-77 | signals imm_sel / register_write_enable / flags_write_enable / alu_valid | lacooda.mmd | mod_cpu_core_sig_imm_sel |
| rtl/cpu/core/cpu_core.sv | 80-82 | signals branch_enable / branch_op / branch_target | lacooda.mmd | mod_cpu_core_sig_branch_enable |
| rtl/cpu/core/cpu_core.sv | 86-89 | signals memory_read_enable / memory_write_enable / memory_op / memory_complete | lacooda.mmd | mod_cpu_core_sig_memory_read_enable |
| rtl/cpu/core/cpu_core.sv | 91 | signal store_data | lacooda.mmd | mod_cpu_core_sig_store_data |
| rtl/cpu/core/cpu_core.sv | 93-94 | signals effective_register_write / effective_flags_write | lacooda.mmd | mod_cpu_core_sig_effective_register_write |
| rtl/cpu/core/cpu_core.sv | 99-123 | instance u_decoder | lacooda.mmd | mod_cpu_core_inst_decoder |
| rtl/cpu/core/cpu_core.sv | 127-128 | assign memory_op | lacooda.mmd | mod_cpu_core_assign_L127 |
| rtl/cpu/core/cpu_core.sv | 132 | assign memory_complete | lacooda.mmd | mod_cpu_core_assign_L132 |
| rtl/cpu/core/cpu_core.sv | 140-144 | assign dbus_valid | lacooda.mmd | mod_cpu_core_assign_L140 |
| rtl/cpu/core/cpu_core.sv | 146 | assign dbus_write | lacooda.mmd | mod_cpu_core_assign_L146 |
| rtl/cpu/core/cpu_core.sv | 149 | assign dbus_addr | lacooda.mmd | mod_cpu_core_assign_L149 |
| rtl/cpu/core/cpu_core.sv | 150 | assign dbus_wdata | lacooda.mmd | mod_cpu_core_assign_L150 |
| rtl/cpu/core/cpu_core.sv | 158-162 | assign effective_register_write | lacooda.mmd | mod_cpu_core_assign_L158 |
| rtl/cpu/core/cpu_core.sv | 164-167 | assign effective_flags_write | lacooda.mmd | mod_cpu_core_assign_L164 |
| rtl/cpu/core/cpu_core.sv | 172-200 | instance u_datapath | lacooda.mmd | mod_cpu_core_inst_datapath |
| rtl/cpu/core/cpu_core.sv | 205-218 | instance u_branch_unit | lacooda.mmd | mod_cpu_core_inst_branch_unit |
| rtl/cpu/core/cpu_core.sv | 222-226 | assign retire_valid | lacooda.mmd | mod_cpu_core_assign_L222 |

## rtl/cpu/cpu.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/cpu.sv | 26-145 | module cpu | lacooda.mmd | mod_cpu |
| rtl/cpu/cpu.sv | 27-29 | input clk / rst / run | lacooda.mmd | mod_cpu_port_clk |
| rtl/cpu/cpu.sv | 32-33 | instr_req / instr_rsp | lacooda.mmd | mod_cpu_port_instr_req |
| rtl/cpu/cpu.sv | 38-39 | data_req / data_rsp | lacooda.mmd | mod_cpu_port_data_req |
| rtl/cpu/cpu.sv | 42-46 | outputs pc / instruction / retire_valid / illegal_instr / alu_result | lacooda.mmd | mod_cpu_port_pc |
| rtl/cpu/cpu.sv | 49-52 | signals instruction_available / decode_valid / core_enable / retire | lacooda.mmd | mod_cpu_sig_instruction_available |
| rtl/cpu/cpu.sv | 54 | signal immediate_word | lacooda.mmd | mod_cpu_sig_immediate_word |
| rtl/cpu/cpu.sv | 56-57 | signals operand_a / operand_b | lacooda.mmd | mod_cpu_sig_operand_a |
| rtl/cpu/cpu.sv | 59-60 | signals flags / status | lacooda.mmd | mod_cpu_sig_flags |
| rtl/cpu/cpu.sv | 62-63 | signals redirect / redirect_target | lacooda.mmd | mod_cpu_sig_redirect |
| rtl/cpu/cpu.sv | 65-68 | signals dbus_valid / dbus_write / dbus_addr / dbus_wdata | lacooda.mmd | mod_cpu_sig_dbus_valid |
| rtl/cpu/cpu.sv | 72-75 | assign data_req.* | lacooda.mmd | mod_cpu_assign_L72 |
| rtl/cpu/cpu.sv | 80 | assign core_enable | lacooda.mmd | mod_cpu_assign_L80 |
| rtl/cpu/cpu.sv | 85-88 | assign retire | lacooda.mmd | mod_cpu_assign_L85 |
| rtl/cpu/cpu.sv | 93-106 | instance u_instruction_fetch | lacooda.mmd | mod_cpu_inst_instruction_fetch |
| rtl/cpu/cpu.sv | 111-143 | instance u_cpu_core | lacooda.mmd | mod_cpu_inst_cpu_core |

## rtl/cpu/fetch/instruction_fetch.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/fetch/instruction_fetch.sv | 28-120 | module instruction_fetch | lacooda.mmd | mod_fetch |
| rtl/cpu/fetch/instruction_fetch.sv | 29-31 | input clk / rst / run | lacooda.mmd | mod_fetch_port_clk |
| rtl/cpu/fetch/instruction_fetch.sv | 34-36 | input retire / redirect / redirect_target | lacooda.mmd | mod_fetch_port_retire |
| rtl/cpu/fetch/instruction_fetch.sv | 39-40 | ibus_req / ibus_rsp | lacooda.mmd | mod_fetch_port_ibus_req |
| rtl/cpu/fetch/instruction_fetch.sv | 43-46 | outputs pc / instruction / immediate_word / instruction_available | lacooda.mmd | mod_fetch_port_pc |
| rtl/cpu/fetch/instruction_fetch.sv | 50-54 | FSM typedef enum fetch_state_e | lacooda.mmd | mod_fetch_fsm_L50 |
| rtl/cpu/fetch/instruction_fetch.sv | 51 | FSM state FETCH_IDLE | lacooda.mmd | mod_fetch_fsm_L50 |
| rtl/cpu/fetch/instruction_fetch.sv | 52 | FSM state FETCH_INSTR | lacooda.mmd | mod_fetch_fsm_L50 |
| rtl/cpu/fetch/instruction_fetch.sv | 53 | FSM state FETCH_IMM | lacooda.mmd | mod_fetch_fsm_L50 |
| rtl/cpu/fetch/instruction_fetch.sv | 56 | signal fetch_state | lacooda.mmd | mod_fetch_sig_fetch_state |
| rtl/cpu/fetch/instruction_fetch.sv | 57 | signal has_imm | lacooda.mmd | mod_fetch_sig_has_imm |
| rtl/cpu/fetch/instruction_fetch.sv | 59-67 | instance u_program_counter | lacooda.mmd | mod_fetch_inst_program_counter |
| rtl/cpu/fetch/instruction_fetch.sv | 71 | assign ibus_req.valid | lacooda.mmd | mod_fetch_assign_L71 |
| rtl/cpu/fetch/instruction_fetch.sv | 72 | assign ibus_req.op = BUS_READ | lacooda.mmd | mod_fetch_assign_L72 |
| rtl/cpu/fetch/instruction_fetch.sv | 73-74 | assign ibus_req.addr | lacooda.mmd | mod_fetch_assign_L73 |
| rtl/cpu/fetch/instruction_fetch.sv | 76 | assign ibus_req.wdata | lacooda.mmd | mod_fetch_assign_L76 |
| rtl/cpu/fetch/instruction_fetch.sv | 80-81 | assign has_imm | lacooda.mmd | mod_fetch_assign_L80 |
| rtl/cpu/fetch/instruction_fetch.sv | 83-118 | always_ff fetch FSM | lacooda.mmd | mod_fetch_ff_L83 |

## rtl/cpu/fetch/program_counter.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/cpu/fetch/program_counter.sv | 8-34 | module program_counter | lacooda.mmd | mod_program_counter |
| rtl/cpu/fetch/program_counter.sv | 9-11 | input clk / rst / enable | lacooda.mmd | mod_program_counter_port_clk |
| rtl/cpu/fetch/program_counter.sv | 13-15 | input redirect / target / has_imm | lacooda.mmd | mod_program_counter_port_redirect |
| rtl/cpu/fetch/program_counter.sv | 17 | output pc | lacooda.mmd | mod_program_counter_port_pc |
| rtl/cpu/fetch/program_counter.sv | 20-32 | always_ff pc update | lacooda.mmd | mod_program_counter_ff_L20 |

## rtl/bus/address_decoder.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/bus/address_decoder.sv | 11-22 | module address_decoder | lacooda.mmd | mod_address_decoder |
| rtl/bus/address_decoder.sv | 12 | input addr | lacooda.mmd | mod_address_decoder_port_addr |
| rtl/bus/address_decoder.sv | 13 | output slave_sel | lacooda.mmd | mod_address_decoder_port_slave_sel |
| rtl/bus/address_decoder.sv | 16-20 | always_comb region compare | lacooda.mmd | mod_address_decoder_comb_L16 |

## rtl/bus/bus_interconnect.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/bus/bus_interconnect.sv | 18-53 | module bus_interconnect | lacooda.mmd | mod_bus_interconnect |
| rtl/bus/bus_interconnect.sv | 19-22 | ports d_req/d_rsp/slave_req/slave_rsp | lacooda.mmd | mod_bus_interconnect_port_d_req |
| rtl/bus/bus_interconnect.sv | 25 | signal slave_sel | lacooda.mmd | mod_bus_interconnect_sig_slave_sel |
| rtl/bus/bus_interconnect.sv | 27-30 | instance u_address_decoder | lacooda.mmd | mod_bus_interconnect_inst_address_decoder |
| rtl/bus/bus_interconnect.sv | 34-37 | assigns slave_req.* | lacooda.mmd | mod_bus_interconnect_assign_L34 |
| rtl/bus/bus_interconnect.sv | 39-51 | always_comb response routing | lacooda.mmd | mod_bus_interconnect_comb_L39 |

## rtl/memory/data_memory.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/memory/data_memory.sv | 26-69 | module data_memory | lacooda.mmd | mod_data_memory |
| rtl/memory/data_memory.sv | 27 | input clk | lacooda.mmd | mod_data_memory_port_clk |
| rtl/memory/data_memory.sv | 29-30 | ports slave_req / slave_rsp | lacooda.mmd | mod_data_memory_port_slave_req |
| rtl/memory/data_memory.sv | 33 | memory mem [0:DATA_MEMORY_COUNT-1] | lacooda.mmd | mod_data_memory_mem |
| rtl/memory/data_memory.sv | 34 | signal addr_valid | lacooda.mmd | mod_data_memory_sig_addr_valid |
| rtl/memory/data_memory.sv | 35 | signal rdata | lacooda.mmd | mod_data_memory_sig_rdata |
| rtl/memory/data_memory.sv | 38-41 | initial zero fill | lacooda.mmd | mod_data_memory_initial_L38 |
| rtl/memory/data_memory.sv | 45 | assign slave_rsp | lacooda.mmd | mod_data_memory_assign_L45 |
| rtl/memory/data_memory.sv | 48-52 | always_comb alignment/range check | lacooda.mmd | mod_data_memory_comb_L48 |
| rtl/memory/data_memory.sv | 55-60 | always_comb read data | lacooda.mmd | mod_data_memory_comb_L55 |
| rtl/memory/data_memory.sv | 63-67 | always_ff store commit | lacooda.mmd | mod_data_memory_ff_L63 |

## rtl/memory/instruction_memory.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/memory/instruction_memory.sv | 22-53 | module instruction_memory | lacooda.mmd | mod_instruction_memory |
| rtl/memory/instruction_memory.sv | 23-24 | ports slave_req / slave_rsp | lacooda.mmd | mod_instruction_memory_port_slave_req |
| rtl/memory/instruction_memory.sv | 27 | memory mem [0:INSTRUCTION_MEMORY_COUNT-1] | lacooda.mmd | mod_instruction_memory_mem |
| rtl/memory/instruction_memory.sv | 28 | signal addr_valid | lacooda.mmd | mod_instruction_memory_sig_addr_valid |
| rtl/memory/instruction_memory.sv | 29 | signal rdata | lacooda.mmd | mod_instruction_memory_sig_rdata |
| rtl/memory/instruction_memory.sv | 31-36 | initial zero fill + $readmemh(PROGRAM_FILE) | lacooda.mmd | mod_instruction_memory_initial_L31 |
| rtl/memory/instruction_memory.sv | 38 | assign slave_rsp | lacooda.mmd | mod_instruction_memory_assign_L38 |
| rtl/memory/instruction_memory.sv | 40-44 | always_comb alignment/range check | lacooda.mmd | mod_instruction_memory_comb_L40 |
| rtl/memory/instruction_memory.sv | 46-51 | always_comb read data | lacooda.mmd | mod_instruction_memory_comb_L46 |

## rtl/soc/cpu_system.sv

| Source | Lines | Construct | Graph | Element |
|---|---:|---|---|---|
| rtl/soc/cpu_system.sv | 16-75 | module cpu_system | lacooda.mmd | mod_cpu_system |
| rtl/soc/cpu_system.sv | 17-19 | input clk / rst / run | lacooda.mmd | mod_cpu_system_port_clk |
| rtl/soc/cpu_system.sv | 21-25 | outputs pc / instruction / retire_valid / illegal_instr / alu_result | lacooda.mmd | mod_cpu_system_port_pc |
| rtl/soc/cpu_system.sv | 29-30 | instr_req / instr_rsp | lacooda.mmd | mod_cpu_system_sig_instr_req |
| rtl/soc/cpu_system.sv | 33-34 | data_req / data_rsp | lacooda.mmd | mod_cpu_system_sig_data_req |
| rtl/soc/cpu_system.sv | 37-38 | slave_req / slave_rsp | lacooda.mmd | mod_cpu_system_sig_slave_req |
| rtl/soc/cpu_system.sv | 40-55 | instance u_cpu | lacooda.mmd | mod_cpu_system_inst_cpu |
| rtl/soc/cpu_system.sv | 57-60 | instance u_instruction_memory | lacooda.mmd | mod_cpu_system_inst_instruction_memory |
| rtl/soc/cpu_system.sv | 62-67 | instance u_bus_interconnect | lacooda.mmd | mod_cpu_system_inst_bus_interconnect |
| rtl/soc/cpu_system.sv | 69-73 | instance u_data_memory | lacooda.mmd | mod_cpu_system_inst_data_memory |
