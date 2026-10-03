# Graph &rarr; RTL index

Inverse index: from an element in `docs/rtl/lacooda.mmd` to exact RTL source.

The `Lines` column is the node marker shown in the graph; where a node
represents a group of constructs, the individual construct lines are listed after it.

| Graph | Element | Meaning | RTL source | Lines (node marker) | Constructs |
|---|---|---|---|---|---|
| docs/rtl/lacooda.mmd | mod_address_decoder | module address_decoder | rtl/bus/address_decoder.sv | L11-L22 | module address_decoder (L11-22) |
| docs/rtl/lacooda.mmd | mod_address_decoder_comb_L16 | always_comb region compare | rtl/bus/address_decoder.sv | L16-L20 | always_comb region compare (L16-20) |
| docs/rtl/lacooda.mmd | mod_address_decoder_port_addr | input addr | rtl/bus/address_decoder.sv | L12 | input addr (L12) |
| docs/rtl/lacooda.mmd | mod_address_decoder_port_slave_sel | output slave_sel | rtl/bus/address_decoder.sv | L13 | output slave_sel (L13) |
| docs/rtl/lacooda.mmd | mod_alu | module alu | rtl/cpu/alu/alu.sv | L22-L165 | module alu (L22-165) |
| docs/rtl/lacooda.mmd | mod_alu_comb_L152 | always_comb flags derivation | rtl/cpu/alu/alu.sv | L152-L163 | always_comb flags derivation (L152-163) |
| docs/rtl/lacooda.mmd | mod_alu_comb_L88 | always_comb result multiplexer | rtl/cpu/alu/alu.sv | L88-L149 | always_comb result multiplexer (L88-149) |
| docs/rtl/lacooda.mmd | mod_alu_inst_arithmetic | instance u_arithmetic | rtl/cpu/alu/alu.sv | L52-L61 | instance u_arithmetic (L52-61) |
| docs/rtl/lacooda.mmd | mod_alu_inst_comparator | instance u_comparator | rtl/cpu/alu/alu.sv | L80-L85 | instance u_comparator (L80-85) |
| docs/rtl/lacooda.mmd | mod_alu_inst_logic_unit | instance u_logic_unit | rtl/cpu/alu/alu.sv | L64-L69 | instance u_logic_unit (L64-69) |
| docs/rtl/lacooda.mmd | mod_alu_inst_shifter | instance u_shifter | rtl/cpu/alu/alu.sv | L72-L77 | instance u_shifter (L72-77) |
| docs/rtl/lacooda.mmd | mod_alu_port_carry_in | input carry_in | rtl/cpu/alu/alu.sv | L25 | input carry_in (L25) |
| docs/rtl/lacooda.mmd | mod_alu_port_flags | output flags : flags_t | rtl/cpu/alu/alu.sv | L28 | output flags : flags_t (L28) |
| docs/rtl/lacooda.mmd | mod_alu_port_op | input op : opcode_t | rtl/cpu/alu/alu.sv | L24 | input op : opcode_t (L24) |
| docs/rtl/lacooda.mmd | mod_alu_port_operand_a | input operand_a | rtl/cpu/alu/alu.sv | L23 | input operand_a (L23) |
| docs/rtl/lacooda.mmd | mod_alu_port_operand_b | input operand_b | rtl/cpu/alu/alu.sv | L23 | input operand_b (L23) |
| docs/rtl/lacooda.mmd | mod_alu_port_result | output result : word_t | rtl/cpu/alu/alu.sv | L27 | output result : word_t (L27) |
| docs/rtl/lacooda.mmd | mod_alu_port_valid | output valid | rtl/cpu/alu/alu.sv | L29 | output valid (L29) |
| docs/rtl/lacooda.mmd | mod_alu_sig_arithmetic_carry | signals arithmetic_carry/overflow/div_zero | rtl/cpu/alu/alu.sv | L42-L44 | signals arithmetic_carry/overflow/div_zero (L42-44) |
| docs/rtl/lacooda.mmd | mod_alu_sig_arithmetic_result | signal arithmetic_result | rtl/cpu/alu/alu.sv | L36 | signal arithmetic_result (L36) |
| docs/rtl/lacooda.mmd | mod_alu_sig_carry_sel | signals carry_sel/overflow_sel/div_zero_sel | rtl/cpu/alu/alu.sv | L47-L49 | signals carry_sel/overflow_sel/div_zero_sel (L47-49) |
| docs/rtl/lacooda.mmd | mod_alu_sig_compare_result | signal compare_result | rtl/cpu/alu/alu.sv | L39 | signal compare_result (L39) |
| docs/rtl/lacooda.mmd | mod_alu_sig_logic_result | signal logic_result | rtl/cpu/alu/alu.sv | L37 | signal logic_result (L37) |
| docs/rtl/lacooda.mmd | mod_alu_sig_shift_result | signal shift_result | rtl/cpu/alu/alu.sv | L38 | signal shift_result (L38) |
| docs/rtl/lacooda.mmd | mod_arithmetic | module arithmetic | rtl/cpu/alu/arithmetic.sv | L18-L167 | module arithmetic (L18-167) |
| docs/rtl/lacooda.mmd | mod_arithmetic_assign_L42 | assign signed_a | rtl/cpu/alu/arithmetic.sv | L42 | assign signed_a (L42) |
| docs/rtl/lacooda.mmd | mod_arithmetic_assign_L43 | assign signed_b | rtl/cpu/alu/arithmetic.sv | L43 | assign signed_b (L43) |
| docs/rtl/lacooda.mmd | mod_arithmetic_assign_L45 | assign min_signed | rtl/cpu/alu/arithmetic.sv | L45 | assign min_signed (L45) |
| docs/rtl/lacooda.mmd | mod_arithmetic_comb_L47 | always_comb arithmetic | rtl/cpu/alu/arithmetic.sv | L47-L165 | always_comb arithmetic (L47-165) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_carry | output carry | rtl/cpu/alu/arithmetic.sv | L24 | output carry (L24) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_carry_in | input carry_in | rtl/cpu/alu/arithmetic.sv | L21 | input carry_in (L21) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_div_zero | output div_zero | rtl/cpu/alu/arithmetic.sv | L26 | output div_zero (L26) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_op | input op | rtl/cpu/alu/arithmetic.sv | L20 | input op (L20) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_operand_a | input operand_a / operand_b | rtl/cpu/alu/arithmetic.sv | L19 | input operand_a / operand_b (L19) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_overflow | output overflow | rtl/cpu/alu/arithmetic.sv | L25 | output overflow (L25) |
| docs/rtl/lacooda.mmd | mod_arithmetic_port_result | output result | rtl/cpu/alu/arithmetic.sv | L23 | output result (L23) |
| docs/rtl/lacooda.mmd | mod_arithmetic_sig_add_ext | signal add_ext | rtl/cpu/alu/arithmetic.sv | L32 | signal add_ext (L32) |
| docs/rtl/lacooda.mmd | mod_arithmetic_sig_min_signed | signal min_signed | rtl/cpu/alu/arithmetic.sv | L38 | signal min_signed (L38) |
| docs/rtl/lacooda.mmd | mod_arithmetic_sig_product | signal product | rtl/cpu/alu/arithmetic.sv | L33 | signal product (L33) |
| docs/rtl/lacooda.mmd | mod_arithmetic_sig_rhs | signal rhs | rtl/cpu/alu/arithmetic.sv | L40 | signal rhs (L40) |
| docs/rtl/lacooda.mmd | mod_arithmetic_sig_signed_a | signals signed_a / signed_b | rtl/cpu/alu/arithmetic.sv | L35-L36 | signals signed_a / signed_b (L35-36) |
| docs/rtl/lacooda.mmd | mod_branch_unit | module branch_unit | rtl/cpu/core/branch_unit.sv | L20-L54 | module branch_unit (L20-54) |
| docs/rtl/lacooda.mmd | mod_branch_unit_comb_L33 | always_comb condition select | rtl/cpu/core/branch_unit.sv | L33-L52 | always_comb condition select (L33-52) |
| docs/rtl/lacooda.mmd | mod_branch_unit_port_enable | input enable | rtl/cpu/core/branch_unit.sv | L21 | input enable (L21) |
| docs/rtl/lacooda.mmd | mod_branch_unit_port_opcode | input opcode | rtl/cpu/core/branch_unit.sv | L22 | input opcode (L22) |
| docs/rtl/lacooda.mmd | mod_branch_unit_port_operand_a | input operand_a / operand_b | rtl/cpu/core/branch_unit.sv | L23-L24 | input operand_a / operand_b (L23-24) |
| docs/rtl/lacooda.mmd | mod_branch_unit_port_redirect | output redirect | rtl/cpu/core/branch_unit.sv | L27 | output redirect (L27) |
| docs/rtl/lacooda.mmd | mod_branch_unit_port_redirect_target | output redirect_target | rtl/cpu/core/branch_unit.sv | L28 | output redirect_target (L28) |
| docs/rtl/lacooda.mmd | mod_branch_unit_port_target | input target | rtl/cpu/core/branch_unit.sv | L25 | input target (L25) |
| docs/rtl/lacooda.mmd | mod_bus_interconnect | module bus_interconnect | rtl/bus/bus_interconnect.sv | L18-L53 | module bus_interconnect (L18-53) |
| docs/rtl/lacooda.mmd | mod_bus_interconnect_assign_L34 | assigns slave_req.* | rtl/bus/bus_interconnect.sv | L34-L37 | assigns slave_req.* (L34-37) |
| docs/rtl/lacooda.mmd | mod_bus_interconnect_comb_L39 | always_comb response routing | rtl/bus/bus_interconnect.sv | L39-L51 | always_comb response routing (L39-51) |
| docs/rtl/lacooda.mmd | mod_bus_interconnect_inst_address_decoder | instance u_address_decoder | rtl/bus/bus_interconnect.sv | L27-L30 | instance u_address_decoder (L27-30) |
| docs/rtl/lacooda.mmd | mod_bus_interconnect_port_d_req | ports d_req/d_rsp/slave_req/slave_rsp | rtl/bus/bus_interconnect.sv | L19-L22 | ports d_req/d_rsp/slave_req/slave_rsp (L19-22) |
| docs/rtl/lacooda.mmd | mod_bus_interconnect_sig_slave_sel | signal slave_sel | rtl/bus/bus_interconnect.sv | L25 | signal slave_sel (L25) |
| docs/rtl/lacooda.mmd | mod_comparator | module comparator | rtl/cpu/alu/comparator.sv | L11-L63 | module comparator (L11-63) |
| docs/rtl/lacooda.mmd | mod_comparator_comb_L20 | always_comb comparisons | rtl/cpu/alu/comparator.sv | L20-L61 | always_comb comparisons (L20-61) |
| docs/rtl/lacooda.mmd | mod_comparator_port_op | input op | rtl/cpu/alu/comparator.sv | L13 | input op (L13) |
| docs/rtl/lacooda.mmd | mod_comparator_port_operand_a | input operand_a / operand_b | rtl/cpu/alu/comparator.sv | L12 | input operand_a / operand_b (L12) |
| docs/rtl/lacooda.mmd | mod_comparator_port_result | output result | rtl/cpu/alu/comparator.sv | L15 | output result (L15) |
| docs/rtl/lacooda.mmd | mod_cpu | module cpu | rtl/cpu/cpu.sv | L26-L145 | module cpu (L26-145) |
| docs/rtl/lacooda.mmd | mod_cpu_assign_L72 | assign data_req.* | rtl/cpu/cpu.sv | L72-L75 | assign data_req.* (L72-75) |
| docs/rtl/lacooda.mmd | mod_cpu_assign_L80 | assign core_enable | rtl/cpu/cpu.sv | L80 | assign core_enable (L80) |
| docs/rtl/lacooda.mmd | mod_cpu_assign_L85 | assign retire | rtl/cpu/cpu.sv | L85-L88 | assign retire (L85-88) |
| docs/rtl/lacooda.mmd | mod_cpu_core | module cpu_core | rtl/cpu/core/cpu_core.sv | L20-L228 | module cpu_core (L20-228) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L127 | assign memory_op | rtl/cpu/core/cpu_core.sv | L127-L128 | assign memory_op (L127-128) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L132 | assign memory_complete | rtl/cpu/core/cpu_core.sv | L132 | assign memory_complete (L132) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L140 | assign dbus_valid | rtl/cpu/core/cpu_core.sv | L140-L144 | assign dbus_valid (L140-144) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L146 | assign dbus_write | rtl/cpu/core/cpu_core.sv | L146 | assign dbus_write (L146) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L149 | assign dbus_addr | rtl/cpu/core/cpu_core.sv | L149 | assign dbus_addr (L149) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L150 | assign dbus_wdata | rtl/cpu/core/cpu_core.sv | L150 | assign dbus_wdata (L150) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L158 | assign effective_register_write | rtl/cpu/core/cpu_core.sv | L158-L162 | assign effective_register_write (L158-162) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L164 | assign effective_flags_write | rtl/cpu/core/cpu_core.sv | L164-L167 | assign effective_flags_write (L164-167) |
| docs/rtl/lacooda.mmd | mod_cpu_core_assign_L222 | assign retire_valid | rtl/cpu/core/cpu_core.sv | L222-L226 | assign retire_valid (L222-226) |
| docs/rtl/lacooda.mmd | mod_cpu_core_inst_branch_unit | instance u_branch_unit | rtl/cpu/core/cpu_core.sv | L205-L218 | instance u_branch_unit (L205-218) |
| docs/rtl/lacooda.mmd | mod_cpu_core_inst_datapath | instance u_datapath | rtl/cpu/core/cpu_core.sv | L172-L200 | instance u_datapath (L172-200) |
| docs/rtl/lacooda.mmd | mod_cpu_core_inst_decoder | instance u_decoder | rtl/cpu/core/cpu_core.sv | L99-L123 | instance u_decoder (L99-123) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_carry_in | input carry_in | rtl/cpu/core/cpu_core.sv | L29 | input carry_in (L29) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_clk | input clk / rst | rtl/cpu/core/cpu_core.sv | L21-L22 | input clk / rst (L21-22) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_core_enable | inputs core_enable / instruction_word / immediate_word | rtl/cpu/core/cpu_core.sv | L24-L26 | inputs core_enable / instruction_word / immediate_word (L24-26) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_dbus_ready | inputs dbus_ready / dbus_rdata | rtl/cpu/core/cpu_core.sv | L35-L36 | inputs dbus_ready / dbus_rdata (L35-36) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_dbus_valid | outputs dbus_valid / dbus_write / dbus_addr / dbus_wdata | rtl/cpu/core/cpu_core.sv | L54-L57 | outputs dbus_valid / dbus_write / dbus_addr / dbus_wdata (L54-57) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_decode_valid | outputs decode_valid / illegal_instr / retire_valid | rtl/cpu/core/cpu_core.sv | L38-L40 | outputs decode_valid / illegal_instr / retire_valid (L38-40) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_flags | outputs flags / status | rtl/cpu/core/cpu_core.sv | L63-L64 | outputs flags / status (L63-64) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_operand_a | outputs operand_a / operand_b / alu_result | rtl/cpu/core/cpu_core.sv | L59-L61 | outputs operand_a / operand_b / alu_result (L59-61) |
| docs/rtl/lacooda.mmd | mod_cpu_core_port_redirect | outputs redirect / redirect_target | rtl/cpu/core/cpu_core.sv | L43-L44 | outputs redirect / redirect_target (L43-44) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_alu_op | signals alu_op / imm_operand | rtl/cpu/core/cpu_core.sv | L71-L72 | signals alu_op / imm_operand (L71-72) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_branch_enable | signals branch_enable / branch_op / branch_target | rtl/cpu/core/cpu_core.sv | L80-L82 | signals branch_enable / branch_op / branch_target (L80-82) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_effective_register_write | signals effective_register_write / effective_flags_write | rtl/cpu/core/cpu_core.sv | L93-L94 | signals effective_register_write / effective_flags_write (L93-94) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_imm_sel | signals imm_sel / register_write_enable / flags_write_enable / alu_valid | rtl/cpu/core/cpu_core.sv | L74-L77 | signals imm_sel / register_write_enable / flags_write_enable / alu_valid (L74-77) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_memory_read_enable | signals memory_read_enable / memory_write_enable / memory_op / memory_complete | rtl/cpu/core/cpu_core.sv | L86-L89 | signals memory_read_enable / memory_write_enable / memory_op / memory_complete (L86-89) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_rs1 | signals rs1 / rs2 / rd | rtl/cpu/core/cpu_core.sv | L67-L69 | signals rs1 / rs2 / rd (L67-69) |
| docs/rtl/lacooda.mmd | mod_cpu_core_sig_store_data | signal store_data | rtl/cpu/core/cpu_core.sv | L91 | signal store_data (L91) |
| docs/rtl/lacooda.mmd | mod_cpu_inst_cpu_core | instance u_cpu_core | rtl/cpu/cpu.sv | L111-L143 | instance u_cpu_core (L111-143) |
| docs/rtl/lacooda.mmd | mod_cpu_inst_instruction_fetch | instance u_instruction_fetch | rtl/cpu/cpu.sv | L93-L106 | instance u_instruction_fetch (L93-106) |
| docs/rtl/lacooda.mmd | mod_cpu_port_clk | input clk / rst / run | rtl/cpu/cpu.sv | L27-L29 | input clk / rst / run (L27-29) |
| docs/rtl/lacooda.mmd | mod_cpu_port_data_req | data_req / data_rsp | rtl/cpu/cpu.sv | L38-L39 | data_req / data_rsp (L38-39) |
| docs/rtl/lacooda.mmd | mod_cpu_port_instr_req | instr_req / instr_rsp | rtl/cpu/cpu.sv | L32-L33 | instr_req / instr_rsp (L32-33) |
| docs/rtl/lacooda.mmd | mod_cpu_port_pc | outputs pc / instruction / retire_valid / illegal_instr / alu_result | rtl/cpu/cpu.sv | L42-L46 | outputs pc / instruction / retire_valid / illegal_instr / alu_result (L42-46) |
| docs/rtl/lacooda.mmd | mod_cpu_sig_dbus_valid | signals dbus_valid / dbus_write / dbus_addr / dbus_wdata | rtl/cpu/cpu.sv | L65-L68 | signals dbus_valid / dbus_write / dbus_addr / dbus_wdata (L65-68) |
| docs/rtl/lacooda.mmd | mod_cpu_sig_flags | signals flags / status | rtl/cpu/cpu.sv | L59-L60 | signals flags / status (L59-60) |
| docs/rtl/lacooda.mmd | mod_cpu_sig_immediate_word | signal immediate_word | rtl/cpu/cpu.sv | L54 | signal immediate_word (L54) |
| docs/rtl/lacooda.mmd | mod_cpu_sig_instruction_available | signals instruction_available / decode_valid / core_enable / retire | rtl/cpu/cpu.sv | L49-L52 | signals instruction_available / decode_valid / core_enable / retire (L49-52) |
| docs/rtl/lacooda.mmd | mod_cpu_sig_operand_a | signals operand_a / operand_b | rtl/cpu/cpu.sv | L56-L57 | signals operand_a / operand_b (L56-57) |
| docs/rtl/lacooda.mmd | mod_cpu_sig_redirect | signals redirect / redirect_target | rtl/cpu/cpu.sv | L62-L63 | signals redirect / redirect_target (L62-63) |
| docs/rtl/lacooda.mmd | mod_cpu_system | module cpu_system | rtl/soc/cpu_system.sv | L16-L75 | module cpu_system (L16-75) |
| docs/rtl/lacooda.mmd | mod_cpu_system_inst_bus_interconnect | instance u_bus_interconnect | rtl/soc/cpu_system.sv | L62-L67 | instance u_bus_interconnect (L62-67) |
| docs/rtl/lacooda.mmd | mod_cpu_system_inst_cpu | instance u_cpu | rtl/soc/cpu_system.sv | L40-L55 | instance u_cpu (L40-55) |
| docs/rtl/lacooda.mmd | mod_cpu_system_inst_data_memory | instance u_data_memory | rtl/soc/cpu_system.sv | L69-L73 | instance u_data_memory (L69-73) |
| docs/rtl/lacooda.mmd | mod_cpu_system_inst_instruction_memory | instance u_instruction_memory | rtl/soc/cpu_system.sv | L57-L60 | instance u_instruction_memory (L57-60) |
| docs/rtl/lacooda.mmd | mod_cpu_system_port_clk | input clk / rst / run | rtl/soc/cpu_system.sv | L17-L19 | input clk / rst / run (L17-19) |
| docs/rtl/lacooda.mmd | mod_cpu_system_port_pc | outputs pc / instruction / retire_valid / illegal_instr / alu_result | rtl/soc/cpu_system.sv | L21-L25 | outputs pc / instruction / retire_valid / illegal_instr / alu_result (L21-25) |
| docs/rtl/lacooda.mmd | mod_cpu_system_sig_data_req | data_req / data_rsp | rtl/soc/cpu_system.sv | L33-L34 | data_req / data_rsp (L33-34) |
| docs/rtl/lacooda.mmd | mod_cpu_system_sig_instr_req | instr_req / instr_rsp | rtl/soc/cpu_system.sv | L29-L30 | instr_req / instr_rsp (L29-30) |
| docs/rtl/lacooda.mmd | mod_cpu_system_sig_slave_req | slave_req / slave_rsp | rtl/soc/cpu_system.sv | L37-L38 | slave_req / slave_rsp (L37-38) |
| docs/rtl/lacooda.mmd | mod_data_memory | module data_memory | rtl/memory/data_memory.sv | L26-L69 | module data_memory (L26-69) |
| docs/rtl/lacooda.mmd | mod_data_memory_assign_L45 | assign slave_rsp | rtl/memory/data_memory.sv | L45 | assign slave_rsp (L45) |
| docs/rtl/lacooda.mmd | mod_data_memory_comb_L48 | always_comb alignment/range check | rtl/memory/data_memory.sv | L48-L52 | always_comb alignment/range check (L48-52) |
| docs/rtl/lacooda.mmd | mod_data_memory_comb_L55 | always_comb read data | rtl/memory/data_memory.sv | L55-L60 | always_comb read data (L55-60) |
| docs/rtl/lacooda.mmd | mod_data_memory_ff_L63 | always_ff store commit | rtl/memory/data_memory.sv | L63-L67 | always_ff store commit (L63-67) |
| docs/rtl/lacooda.mmd | mod_data_memory_initial_L38 | initial zero fill | rtl/memory/data_memory.sv | L38-L41 | initial zero fill (L38-41) |
| docs/rtl/lacooda.mmd | mod_data_memory_mem | memory mem [0:DATA_MEMORY_COUNT-1] | rtl/memory/data_memory.sv | L33 | memory mem [0:DATA_MEMORY_COUNT-1] (L33) |
| docs/rtl/lacooda.mmd | mod_data_memory_port_clk | input clk | rtl/memory/data_memory.sv | L27 | input clk (L27) |
| docs/rtl/lacooda.mmd | mod_data_memory_port_slave_req | ports slave_req / slave_rsp | rtl/memory/data_memory.sv | L29-L30 | ports slave_req / slave_rsp (L29-30) |
| docs/rtl/lacooda.mmd | mod_data_memory_sig_addr_valid | signal addr_valid | rtl/memory/data_memory.sv | L34 | signal addr_valid (L34) |
| docs/rtl/lacooda.mmd | mod_data_memory_sig_rdata | signal rdata | rtl/memory/data_memory.sv | L35 | signal rdata (L35) |
| docs/rtl/lacooda.mmd | mod_datapath | module datapath | rtl/cpu/core/datapath.sv | L25-L144 | module datapath (L25-144) |
| docs/rtl/lacooda.mmd | mod_datapath_assign_L103 | assign operand_b (imm mux) | rtl/cpu/core/datapath.sv | L103-L104 | assign operand_b (imm mux) (L103-104) |
| docs/rtl/lacooda.mmd | mod_datapath_assign_L128 | assign writeback_data | rtl/cpu/core/datapath.sv | L128-L129 | assign writeback_data (L128-129) |
| docs/rtl/lacooda.mmd | mod_datapath_assign_L71 | assign register_wen | rtl/cpu/core/datapath.sv | L71-L72 | assign register_wen (L71-72) |
| docs/rtl/lacooda.mmd | mod_datapath_assign_L74 | assign flags_wen | rtl/cpu/core/datapath.sv | L74-L75 | assign flags_wen (L74-75) |
| docs/rtl/lacooda.mmd | mod_datapath_assign_L97 | assign store_data | rtl/cpu/core/datapath.sv | L97 | assign store_data (L97) |
| docs/rtl/lacooda.mmd | mod_datapath_inst_alu | instance u_alu | rtl/cpu/core/datapath.sv | L110-L120 | instance u_alu (L110-120) |
| docs/rtl/lacooda.mmd | mod_datapath_inst_register_file | instance u_register_file | rtl/cpu/core/datapath.sv | L81-L94 | instance u_register_file (L81-94) |
| docs/rtl/lacooda.mmd | mod_datapath_inst_status_register | instance u_status_register | rtl/cpu/core/datapath.sv | L135-L142 | instance u_status_register (L135-142) |
| docs/rtl/lacooda.mmd | mod_datapath_port_alu_op | inputs alu_op / carry_in | rtl/cpu/core/datapath.sv | L35-L36 | inputs alu_op / carry_in (L35-36) |
| docs/rtl/lacooda.mmd | mod_datapath_port_clk | input clk / rst | rtl/cpu/core/datapath.sv | L26-L27 | input clk / rst (L26-27) |
| docs/rtl/lacooda.mmd | mod_datapath_port_dmem_rdata | inputs dmem_rdata / writeback_from_mem | rtl/cpu/core/datapath.sv | L47-L48 | inputs dmem_rdata / writeback_from_mem (L47-48) |
| docs/rtl/lacooda.mmd | mod_datapath_port_flags | outputs flags / status | rtl/cpu/core/datapath.sv | L58-L59 | outputs flags / status (L58-59) |
| docs/rtl/lacooda.mmd | mod_datapath_port_imm_operand | inputs imm_operand / imm_sel | rtl/cpu/core/datapath.sv | L39-L40 | inputs imm_operand / imm_sel (L39-40) |
| docs/rtl/lacooda.mmd | mod_datapath_port_operand_a | outputs operand_a/operand_b/store_data/alu_result/alu_valid | rtl/cpu/core/datapath.sv | L51-L55 | outputs operand_a/operand_b/store_data/alu_result/alu_valid (L51-55) |
| docs/rtl/lacooda.mmd | mod_datapath_port_register_write_enable | inputs register_write_enable / flags_write_enable | rtl/cpu/core/datapath.sv | L43-L44 | inputs register_write_enable / flags_write_enable (L43-44) |
| docs/rtl/lacooda.mmd | mod_datapath_port_rs1 | inputs rs1 / rs2 / rd | rtl/cpu/core/datapath.sv | L30-L32 | inputs rs1 / rs2 / rd (L30-32) |
| docs/rtl/lacooda.mmd | mod_datapath_sig_register_wen | signals register_wen / flags_wen | rtl/cpu/core/datapath.sv | L64-L65 | signals register_wen / flags_wen (L64-65) |
| docs/rtl/lacooda.mmd | mod_datapath_sig_rs2_data | signals rs2_data / writeback_data | rtl/cpu/core/datapath.sv | L61-L62 | signals rs2_data / writeback_data (L61-62) |
| docs/rtl/lacooda.mmd | mod_decoder | module decoder | rtl/cpu/core/decoder.sv | L20-L238 | module decoder (L20-238) |
| docs/rtl/lacooda.mmd | mod_decoder_assign_L67 | assign instr_fields = instruction | rtl/cpu/core/decoder.sv | L67 | assign instr_fields = instruction (L67) |
| docs/rtl/lacooda.mmd | mod_decoder_comb_L163 | always_comb control generation | rtl/cpu/core/decoder.sv | L163-L236 | always_comb control generation (L163-236) |
| docs/rtl/lacooda.mmd | mod_decoder_comb_L72 | always_comb format validation | rtl/cpu/core/decoder.sv | L72-L158 | always_comb format validation (L72-158) |
| docs/rtl/lacooda.mmd | mod_decoder_port_alu_op | outputs alu_op / imm_operand / imm_sel | rtl/cpu/core/decoder.sv | L28-L30 | outputs alu_op / imm_operand / imm_sel (L28-30) |
| docs/rtl/lacooda.mmd | mod_decoder_port_branch_enable | outputs branch_enable / branch_op / branch_target | rtl/cpu/core/decoder.sv | L36-L38 | outputs branch_enable / branch_op / branch_target (L36-38) |
| docs/rtl/lacooda.mmd | mod_decoder_port_decode_valid | outputs decode_valid / illegal_instr | rtl/cpu/core/decoder.sv | L44-L45 | outputs decode_valid / illegal_instr (L44-45) |
| docs/rtl/lacooda.mmd | mod_decoder_port_immediate_word | input immediate_word | rtl/cpu/core/decoder.sv | L22 | input immediate_word (L22) |
| docs/rtl/lacooda.mmd | mod_decoder_port_instruction | input instruction | rtl/cpu/core/decoder.sv | L21 | input instruction (L21) |
| docs/rtl/lacooda.mmd | mod_decoder_port_memory_read_enable | outputs memory_read_enable / memory_write_enable | rtl/cpu/core/decoder.sv | L41-L42 | outputs memory_read_enable / memory_write_enable (L41-42) |
| docs/rtl/lacooda.mmd | mod_decoder_port_register_write_enable | outputs register_write_enable / flags_write_enable | rtl/cpu/core/decoder.sv | L32-L33 | outputs register_write_enable / flags_write_enable (L32-33) |
| docs/rtl/lacooda.mmd | mod_decoder_port_rs1 | outputs rs1 / rs2 / rd | rtl/cpu/core/decoder.sv | L24-L26 | outputs rs1 / rs2 / rd (L24-26) |
| docs/rtl/lacooda.mmd | mod_decoder_sig_branch_qual | signals branch_qual / memory_qual | rtl/cpu/core/decoder.sv | L58-L59 | signals branch_qual / memory_qual (L58-59) |
| docs/rtl/lacooda.mmd | mod_decoder_sig_instr_fields | signal instr_fields | rtl/cpu/core/decoder.sv | L51 | signal instr_fields (L51) |
| docs/rtl/lacooda.mmd | mod_decoder_sig_load_qual | signals load_qual / store_qual | rtl/cpu/core/decoder.sv | L60-L61 | signals load_qual / store_qual (L60-61) |
| docs/rtl/lacooda.mmd | mod_decoder_sig_opcode_valid | signals opcode_valid / format_valid | rtl/cpu/core/decoder.sv | L53-L54 | signals opcode_valid / format_valid (L53-54) |
| docs/rtl/lacooda.mmd | mod_decoder_sig_unary_qual | signals unary_qual / mov_qual / movi_qual | rtl/cpu/core/decoder.sv | L55-L57 | signals unary_qual / mov_qual / movi_qual (L55-57) |
| docs/rtl/lacooda.mmd | mod_fetch | module instruction_fetch | rtl/cpu/fetch/instruction_fetch.sv | L28-L120 | module instruction_fetch (L28-120) |
| docs/rtl/lacooda.mmd | mod_fetch_assign_L71 | assign ibus_req.valid | rtl/cpu/fetch/instruction_fetch.sv | L71 | assign ibus_req.valid (L71) |
| docs/rtl/lacooda.mmd | mod_fetch_assign_L72 | assign ibus_req.op = BUS_READ | rtl/cpu/fetch/instruction_fetch.sv | L72 | assign ibus_req.op = BUS_READ (L72) |
| docs/rtl/lacooda.mmd | mod_fetch_assign_L73 | assign ibus_req.addr | rtl/cpu/fetch/instruction_fetch.sv | L73-L74 | assign ibus_req.addr (L73-74) |
| docs/rtl/lacooda.mmd | mod_fetch_assign_L76 | assign ibus_req.wdata | rtl/cpu/fetch/instruction_fetch.sv | L76 | assign ibus_req.wdata (L76) |
| docs/rtl/lacooda.mmd | mod_fetch_assign_L80 | assign has_imm | rtl/cpu/fetch/instruction_fetch.sv | L80-L81 | assign has_imm (L80-81) |
| docs/rtl/lacooda.mmd | mod_fetch_ff_L83 | always_ff fetch FSM | rtl/cpu/fetch/instruction_fetch.sv | L83-L118 | always_ff fetch FSM (L83-118) |
| docs/rtl/lacooda.mmd | mod_fetch_fsm_L50 | FSM typedef enum fetch_state_e | rtl/cpu/fetch/instruction_fetch.sv | L50-L54 | FSM typedef enum fetch_state_e (L50-54)<br/>FSM state FETCH_IDLE (L51)<br/>FSM state FETCH_INSTR (L52)<br/>FSM state FETCH_IMM (L53) |
| docs/rtl/lacooda.mmd | mod_fetch_inst_program_counter | instance u_program_counter | rtl/cpu/fetch/instruction_fetch.sv | L59-L67 | instance u_program_counter (L59-67) |
| docs/rtl/lacooda.mmd | mod_fetch_port_clk | input clk / rst / run | rtl/cpu/fetch/instruction_fetch.sv | L29-L31 | input clk / rst / run (L29-31) |
| docs/rtl/lacooda.mmd | mod_fetch_port_ibus_req | ibus_req / ibus_rsp | rtl/cpu/fetch/instruction_fetch.sv | L39-L40 | ibus_req / ibus_rsp (L39-40) |
| docs/rtl/lacooda.mmd | mod_fetch_port_pc | outputs pc / instruction / immediate_word / instruction_available | rtl/cpu/fetch/instruction_fetch.sv | L43-L46 | outputs pc / instruction / immediate_word / instruction_available (L43-46) |
| docs/rtl/lacooda.mmd | mod_fetch_port_retire | input retire / redirect / redirect_target | rtl/cpu/fetch/instruction_fetch.sv | L34-L36 | input retire / redirect / redirect_target (L34-36) |
| docs/rtl/lacooda.mmd | mod_fetch_sig_fetch_state | signal fetch_state | rtl/cpu/fetch/instruction_fetch.sv | L56 | signal fetch_state (L56) |
| docs/rtl/lacooda.mmd | mod_fetch_sig_has_imm | signal has_imm | rtl/cpu/fetch/instruction_fetch.sv | L57 | signal has_imm (L57) |
| docs/rtl/lacooda.mmd | mod_instruction_memory | module instruction_memory | rtl/memory/instruction_memory.sv | L22-L53 | module instruction_memory (L22-53) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_assign_L38 | assign slave_rsp | rtl/memory/instruction_memory.sv | L38 | assign slave_rsp (L38) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_comb_L40 | always_comb alignment/range check | rtl/memory/instruction_memory.sv | L40-L44 | always_comb alignment/range check (L40-44) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_comb_L46 | always_comb read data | rtl/memory/instruction_memory.sv | L46-L51 | always_comb read data (L46-51) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_initial_L31 | initial zero fill + $readmemh(PROGRAM_FILE) | rtl/memory/instruction_memory.sv | L31-L36 | initial zero fill + $readmemh(PROGRAM_FILE) (L31-36) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_mem | memory mem [0:INSTRUCTION_MEMORY_COUNT-1] | rtl/memory/instruction_memory.sv | L27 | memory mem [0:INSTRUCTION_MEMORY_COUNT-1] (L27) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_port_slave_req | ports slave_req / slave_rsp | rtl/memory/instruction_memory.sv | L23-L24 | ports slave_req / slave_rsp (L23-24) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_sig_addr_valid | signal addr_valid | rtl/memory/instruction_memory.sv | L28 | signal addr_valid (L28) |
| docs/rtl/lacooda.mmd | mod_instruction_memory_sig_rdata | signal rdata | rtl/memory/instruction_memory.sv | L29 | signal rdata (L29) |
| docs/rtl/lacooda.mmd | mod_logic_unit | module logic_unit | rtl/cpu/alu/logic_unit.sv | L10-L37 | module logic_unit (L10-37) |
| docs/rtl/lacooda.mmd | mod_logic_unit_comb_L19 | always_comb bitwise ops | rtl/cpu/alu/logic_unit.sv | L19-L35 | always_comb bitwise ops (L19-35) |
| docs/rtl/lacooda.mmd | mod_logic_unit_port_op | input op | rtl/cpu/alu/logic_unit.sv | L12 | input op (L12) |
| docs/rtl/lacooda.mmd | mod_logic_unit_port_operand_a | input operand_a / operand_b | rtl/cpu/alu/logic_unit.sv | L11 | input operand_a / operand_b (L11) |
| docs/rtl/lacooda.mmd | mod_logic_unit_port_result | output result | rtl/cpu/alu/logic_unit.sv | L14 | output result (L14) |
| docs/rtl/lacooda.mmd | mod_program_counter | module program_counter | rtl/cpu/fetch/program_counter.sv | L8-L34 | module program_counter (L8-34) |
| docs/rtl/lacooda.mmd | mod_program_counter_ff_L20 | always_ff pc update | rtl/cpu/fetch/program_counter.sv | L20-L32 | always_ff pc update (L20-32) |
| docs/rtl/lacooda.mmd | mod_program_counter_port_clk | input clk / rst / enable | rtl/cpu/fetch/program_counter.sv | L9-L11 | input clk / rst / enable (L9-11) |
| docs/rtl/lacooda.mmd | mod_program_counter_port_pc | output pc | rtl/cpu/fetch/program_counter.sv | L17 | output pc (L17) |
| docs/rtl/lacooda.mmd | mod_program_counter_port_redirect | input redirect / target / has_imm | rtl/cpu/fetch/program_counter.sv | L13-L15 | input redirect / target / has_imm (L13-15) |
| docs/rtl/lacooda.mmd | mod_register_file | module register_file | rtl/cpu/core/register_file.sv | L12-L38 | module register_file (L12-38) |
| docs/rtl/lacooda.mmd | mod_register_file_assign_L26 | assign rs1_data (R0 reads 0) | rtl/cpu/core/register_file.sv | L26 | assign rs1_data (R0 reads 0) (L26) |
| docs/rtl/lacooda.mmd | mod_register_file_assign_L27 | assign rs2_data (R0 reads 0) | rtl/cpu/core/register_file.sv | L27 | assign rs2_data (R0 reads 0) (L27) |
| docs/rtl/lacooda.mmd | mod_register_file_ff_L30 | always_ff reset clear + write | rtl/cpu/core/register_file.sv | L30-L37 | always_ff reset clear + write (L30-37) |
| docs/rtl/lacooda.mmd | mod_register_file_mem_registers | memory registers [0:REG_FILE_COUNT-1] | rtl/cpu/core/register_file.sv | L23 | memory registers [0:REG_FILE_COUNT-1] (L23) |
| docs/rtl/lacooda.mmd | mod_register_file_port_clk | input clk / rst | rtl/cpu/core/register_file.sv | L13-L14 | input clk / rst (L13-14) |
| docs/rtl/lacooda.mmd | mod_register_file_port_rs1_addr | rs1_addr / rs1_data | rtl/cpu/core/register_file.sv | L15-L16 | rs1_addr / rs1_data (L15-16) |
| docs/rtl/lacooda.mmd | mod_register_file_port_rs2_addr | rs2_addr / rs2_data | rtl/cpu/core/register_file.sv | L17-L18 | rs2_addr / rs2_data (L17-18) |
| docs/rtl/lacooda.mmd | mod_register_file_port_write_enable | write_enable / write_addr / write_data | rtl/cpu/core/register_file.sv | L19-L21 | write_enable / write_addr / write_data (L19-21) |
| docs/rtl/lacooda.mmd | mod_register_file_sig_idx | integer idx | rtl/cpu/core/register_file.sv | L29 | integer idx (L29) |
| docs/rtl/lacooda.mmd | mod_shifter | module shifter | rtl/cpu/alu/shifter.sv | L10-L54 | module shifter (L10-54) |
| docs/rtl/lacooda.mmd | mod_shifter_assign_L24 | assign shift_amount | rtl/cpu/alu/shifter.sv | L24 | assign shift_amount (L24) |
| docs/rtl/lacooda.mmd | mod_shifter_comb_L26 | always_comb shifts/rotates | rtl/cpu/alu/shifter.sv | L26-L52 | always_comb shifts/rotates (L26-52) |
| docs/rtl/lacooda.mmd | mod_shifter_param_SHIFT_WIDTH | localparam SHIFT_WIDTH | rtl/cpu/alu/shifter.sv | L19 | localparam SHIFT_WIDTH (L19) |
| docs/rtl/lacooda.mmd | mod_shifter_port_op | input op | rtl/cpu/alu/shifter.sv | L12 | input op (L12) |
| docs/rtl/lacooda.mmd | mod_shifter_port_operand_a | input operand_a / operand_b | rtl/cpu/alu/shifter.sv | L11 | input operand_a / operand_b (L11) |
| docs/rtl/lacooda.mmd | mod_shifter_port_result | output result | rtl/cpu/alu/shifter.sv | L14 | output result (L14) |
| docs/rtl/lacooda.mmd | mod_shifter_sig_shift_amount | signal shift_amount | rtl/cpu/alu/shifter.sv | L21 | signal shift_amount (L21) |
| docs/rtl/lacooda.mmd | mod_status_register | module status_register | rtl/cpu/core/status_register.sv | L14-L39 | module status_register (L14-39) |
| docs/rtl/lacooda.mmd | mod_status_register_assign_L35 | assign status {DZ,V,C,N,Z} | rtl/cpu/core/status_register.sv | L35-L37 | assign status {DZ,V,C,N,Z} (L35-37) |
| docs/rtl/lacooda.mmd | mod_status_register_ff_L25 | always_ff flag storage | rtl/cpu/core/status_register.sv | L25-L33 | always_ff flag storage (L25-33) |
| docs/rtl/lacooda.mmd | mod_status_register_port_clk | input clk / rst / write_enable | rtl/cpu/core/status_register.sv | L15-L17 | input clk / rst / write_enable (L15-17) |
| docs/rtl/lacooda.mmd | mod_status_register_port_flags_in | input flags_in | rtl/cpu/core/status_register.sv | L19 | input flags_in (L19) |
| docs/rtl/lacooda.mmd | mod_status_register_port_status | output status | rtl/cpu/core/status_register.sv | L20 | output status (L20) |
| docs/rtl/lacooda.mmd | mod_status_register_sig_flags_reg | signal flags_reg | rtl/cpu/core/status_register.sv | L23 | signal flags_reg (L23) |
| docs/rtl/lacooda.mmd | pkg_bus | package bus_pkg | rtl/packages/bus_pkg.sv | L13-L49 | package bus_pkg (L13-49) |
| docs/rtl/lacooda.mmd | pkg_bus_pkg_enum_bus_op_t | typedef enum bus_op_t (BUS_READ/BUS_WRITE) | rtl/packages/bus_pkg.sv | L15-L18 | typedef enum bus_op_t (BUS_READ/BUS_WRITE) (L15-18) |
| docs/rtl/lacooda.mmd | pkg_bus_pkg_param_DATA_MEMORY_BASE | localparam DATA_MEMORY_BASE | rtl/packages/bus_pkg.sv | L36 | localparam DATA_MEMORY_BASE (L36) |
| docs/rtl/lacooda.mmd | pkg_bus_pkg_param_DATA_MEMORY_LIMIT | localparam DATA_MEMORY_LIMIT | rtl/packages/bus_pkg.sv | L46-L47 | localparam DATA_MEMORY_LIMIT (L46-47) |
| docs/rtl/lacooda.mmd | pkg_bus_pkg_param_DATA_MEMORY_SIZE | localparam DATA_MEMORY_SIZE | rtl/packages/bus_pkg.sv | L42-L44 | localparam DATA_MEMORY_SIZE (L42-44) |
| docs/rtl/lacooda.mmd | pkg_bus_pkg_struct_bus_req_t | typedef struct bus_req_t (valid op addr wdata) | rtl/packages/bus_pkg.sv | L21-L26 | typedef struct bus_req_t (valid op addr wdata) (L21-26) |
| docs/rtl/lacooda.mmd | pkg_bus_pkg_struct_bus_rsp_t | typedef struct bus_rsp_t (ready rdata) | rtl/packages/bus_pkg.sv | L28-L31 | typedef struct bus_rsp_t (ready rdata) (L28-31) |
| docs/rtl/lacooda.mmd | pkg_cpu | package cpu_pkg | rtl/packages/cpu_pkg.sv | L24-L257 | package cpu_pkg (L24-257) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_encode_branch | function encode_branch | rtl/packages/cpu_pkg.sv | L211-L222 | function encode_branch (L211-222) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_encode_instruction | function encode_instruction | rtl/packages/cpu_pkg.sv | L193-L207 | function encode_instruction (L193-207) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_encode_jump | function encode_jump | rtl/packages/cpu_pkg.sv | L225-L227 | function encode_jump (L225-227) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_encode_load | function encode_load | rtl/packages/cpu_pkg.sv | L231-L241 | function encode_load (L231-241) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_encode_store | function encode_store | rtl/packages/cpu_pkg.sv | L245-L255 | function encode_store (L245-255) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_instr_uses_imm | function instr_uses_imm | rtl/packages/cpu_pkg.sv | L185-L189 | function instr_uses_imm (L185-189) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_make_flags | function make_flags | rtl/packages/cpu_pkg.sv | L101-L111 | function make_flags (L101-111) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_uses_imm | function uses_imm | rtl/packages/cpu_pkg.sv | L178-L183 | function uses_imm (L178-183) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_func_validate_configuration | function validate_configuration | rtl/packages/cpu_pkg.sv | L135-L156 | function validate_configuration (L135-156) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_macro_LACOODA_WORD_WIDTH | macro LACOODA_WORD_WIDTH (default 64) | rtl/packages/cpu_pkg.sv | L35-L37 | macro LACOODA_WORD_WIDTH (default 64) (L35-37) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_DATA_MEMORY_COUNT | localparam DATA_MEMORY_COUNT | rtl/packages/cpu_pkg.sv | L70 | localparam DATA_MEMORY_COUNT (L70) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_INSTRUCTION_MEMORY_COUNT | localparam INSTRUCTION_MEMORY_COUNT | rtl/packages/cpu_pkg.sv | L69 | localparam INSTRUCTION_MEMORY_COUNT (L69) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_LAYOUT | localparam RS2_LSB / RS2_MSB | rtl/packages/cpu_pkg.sv | L119-L132 | localparam RS2_LSB / RS2_MSB (L119-120)<br/>localparam RS1_LSB / RS1_MSB (L121-122)<br/>localparam RD_LSB / RD_MSB (L123-124)<br/>localparam OPCODE_LSB / OPCODE_MSB (L125-126)<br/>localparam IMM_MODE_BIT (L127)<br/>localparam UPDATE_STATUS_BIT (L128)<br/>localparam RESERVED_LSB / RESERVED_MSB (L129-130)<br/>localparam USED_INSTRUCTION_BITS / RESERVED_WIDTH (L131-132) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_PROGRAM_FILE | localparam PROGRAM_FILE (word-width dependent) | rtl/packages/cpu_pkg.sv | L73-L74 | localparam PROGRAM_FILE (word-width dependent) (L73-74) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_REG_FILE_ADDR_WIDTH | localparam REG_FILE_ADDR_WIDTH | rtl/packages/cpu_pkg.sv | L58 | localparam REG_FILE_ADDR_WIDTH (L58) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_REG_FILE_COUNT | localparam REG_FILE_COUNT | rtl/packages/cpu_pkg.sv | L57 | localparam REG_FILE_COUNT (L57) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_STATUS_WIDTH | localparam STATUS_WIDTH = 32 | rtl/packages/cpu_pkg.sv | L83 | localparam STATUS_WIDTH = 32 (L83) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_WORD_BYTES | localparam WORD_BYTES | rtl/packages/cpu_pkg.sv | L40 | localparam WORD_BYTES (L40) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_WORD_WIDTH | localparam WORD_WIDTH | rtl/packages/cpu_pkg.sv | L39 | localparam WORD_WIDTH (L39) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_param_ZERO_REG | localparam ZERO_REG | rtl/packages/cpu_pkg.sv | L63 | localparam ZERO_REG (L63) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_type_flags_t | typedef struct flags_t (Z N C V DZ) | rtl/packages/cpu_pkg.sv | L93-L99 | typedef struct flags_t (Z N C V DZ) (L93-99) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_type_instr_fields_t | typedef struct instr_fields_t | rtl/packages/cpu_pkg.sv | L160-L167 | typedef struct instr_fields_t (L160-167) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_type_instruction_t | typedef instruction_t | rtl/packages/cpu_pkg.sv | L51 | typedef instruction_t (L51) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_type_reg_addr_t | typedef reg_addr_t | rtl/packages/cpu_pkg.sv | L60 | typedef reg_addr_t (L60) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_type_status_t | typedef status_t | rtl/packages/cpu_pkg.sv | L85 | typedef status_t (L85) |
| docs/rtl/lacooda.mmd | pkg_cpu_pkg_type_word_t | typedef word_t | rtl/packages/cpu_pkg.sv | L48 | typedef word_t (L48) |
| docs/rtl/lacooda.mmd | pkg_opcode | package opcode_pkg | rtl/packages/opcode_pkg.sv | L22-L133 | package opcode_pkg (L22-133) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_enum_opcode_e | typedef enum opcode_e (ALU_/CTRL_/MEM_ codepoints) | rtl/packages/opcode_pkg.sv | L28-L88 | typedef enum opcode_e (ALU_/CTRL_/MEM_ codepoints) (L28-88) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_alu_opcode | function is_alu_opcode | rtl/packages/opcode_pkg.sv | L109-L111 | function is_alu_opcode (L109-111) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_branch_opcode | function is_branch_opcode | rtl/packages/opcode_pkg.sv | L125-L127 | function is_branch_opcode (L125-127) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_memory_opcode | function is_memory_opcode | rtl/packages/opcode_pkg.sv | L129-L131 | function is_memory_opcode (L129-131) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_mov_op | function is_mov_op | rtl/packages/opcode_pkg.sv | L117-L119 | function is_mov_op (L117-119) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_movi_op | function is_movi_op | rtl/packages/opcode_pkg.sv | L121-L123 | function is_movi_op (L121-123) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_unary_opcode | function is_unary_opcode | rtl/packages/opcode_pkg.sv | L113-L115 | function is_unary_opcode (L113-115) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_func_is_valid_opcode | function is_valid_opcode | rtl/packages/opcode_pkg.sv | L105-L107 | function is_valid_opcode (L105-107) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_param_ALU_OPCODE_COUNT | localparam ALU_OPCODE_COUNT | rtl/packages/opcode_pkg.sv | L94 | localparam ALU_OPCODE_COUNT (L94) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_param_OPCODE_COUNT | localparam OPCODE_COUNT | rtl/packages/opcode_pkg.sv | L97 | localparam OPCODE_COUNT (L97) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_param_OPCODE_WIDTH | localparam OPCODE_WIDTH | rtl/packages/opcode_pkg.sv | L26 | localparam OPCODE_WIDTH (L26) |
| docs/rtl/lacooda.mmd | pkg_opcode_pkg_type_opcode_t | typedef opcode_t | rtl/packages/opcode_pkg.sv | L91 | typedef opcode_t (L91) |
