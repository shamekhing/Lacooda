# LACOODA — As-Built Architecture Reference

This document is the **code-grounded map of the LACOODA hardware as it is
wired today**. It walks the design from the FPGA board top (`fpga_top`) down to
the smallest operations inside the ALU (a single 1-bit adder), naming the real
files, modules, ports and constants at every step.

It is a *reference*, not a tutorial. `README.md` teaches the design story; this
file answers "what is in the tree right now, how is it connected, and how does
one instruction flow end to end".

**Scope rule used throughout:** only modules that are actually instantiated in
the live hierarchy rooted at `fpga_top` are documented in detail. Modules that
exist in the tree but are **not wired** (`gpu_core`, `pixel_engine`,
`gpu_memory`, reserved DDR3, the empty `gpu_decoder.sv`) are listed once in
[Appendix F](#appendix-f--not-wired--reserved).

---

## Table of Contents

1. [System Summary](#1-system-summary)
2. [Repository Layout](#2-repository-layout)
3. [The Layered Mental Model](#3-the-layered-mental-model)
4. [Foundation: The Packages](#4-foundation-the-packages)
5. [The Bus Contract](#5-the-bus-contract)
6. [Memory Subsystem](#6-memory-subsystem)
7. [CPU — Top to Bottom](#7-cpu--top-to-bottom)
8. [The ALU — Unit to Bit Operations](#8-the-alu--unit-to-bit-operations)
9. [GPU (Wired Part)](#9-gpu-wired-part)
10. [Board Top and Build](#10-board-top-and-build)
11. [Reference Appendices](#11-reference-appendices)

---

## 1. System Summary

LACOODA is a small 32-bit RISC-like SoC written in SystemVerilog and targeted at
the **Sipeed Tang Primer 20K** (Gowin `GW2A-18C`), clocked by the onboard
**27 MHz** oscillator.

It is built from five subsystems:

| Subsystem | Top module | Role |
| --- | --- | --- |
| CPU | `cpu` | Fetch, decode, execute; I-BUS + D-BUS bus master |
| Bus | `bus_interconnect` (+ `address_decoder`) | Routes CPU data accesses to slaves |
| Memory | `memory_subsystem` | Instruction ROM + data BRAM |
| GPU | `gpu` | CPU-visible MMIO register block |
| Board | `fpga_top` | Pins, buttons, LEDs; wraps `system` |

Key architectural facts:

* **Architectural word = 32 bits** (`cpu_pkg::WORD_WIDTH`). The design is locked
  to 32 bits.
* **64 registers**, R0 hardwired to zero.
* **Fixed-shape instructions**: register/opcode fields packed in the low 26 bits
  of one word; an optional **immediate word follows** the instruction as a
  second full word.
* **Multi-cycle, bit-serial ALU**: every ALU op takes roughly `WORD_WIDTH` clock
  cycles and shares a single 1-bit adder.
* **Single bus master** (the CPU data port). Memory and MMIO are slaves.
* Memory-mapped I/O: data RAM at `0x00000000`, GPU registers at `0x10000000`.

---

## 2. Repository Layout

| Path | Contents |
| --- | --- |
| `src/rtl/packages/` | Shared types/constants (`opcode_pkg`, `cpu_pkg`, `memory_pkg`, `bus_pkg`, `gpu_pkg`, `alu_pkg`) |
| `src/rtl/bus/` | `address_decoder`, `bus_interconnect` |
| `src/rtl/cpu/` | `cpu` top; `fetch/`, `core/`, `alu/` sub-folders |
| `src/rtl/memory/` | `instruction_memory`, `data_memory`, `memory_subsystem` (plus unused `gpu_memory`) |
| `src/rtl/gpu/` | `gpu` top, `core/gpu_register` (plus unused `gpu_core`, `pixel_engine`, empty `gpu_decoder`) |
| `src/rtl/soc/` | `system` (SoC), `fpga_top` (board wrapper) |
| `src/sim/testbench/` | Unit + integration testbenches (`cpu/`, `bus/`, `memory/`, `gpu/`, `soc/`) |
| `src/sim/build/`, `src/sim/waveforms/` | Compiled sims and VCD dumps (git-ignored) |
| `src/programs/` | Hex memory images (`genesis_*.hex`, `data_memory_*.hex`) |
| `src/constraints/` | `sipeed_tang_primer_20k.cst` (pins), `.sdc` (clock) |
| `run.sh` | Icarus Verilog regression + GTKWave launcher |
| `lacooda.gprj` | Gowin IDE project file list |

Build/verification tooling: **Icarus Verilog** (`iverilog -g2012 -Wall`) for
simulation, **Gowin** for synthesis/PnR, `.vscode/settings.json` configures
`slang`/`verilator` lint and `verible` formatting.

---

## 3. The Layered Mental Model

The design is best read as a stack. Each layer is a strict container of the one
below it:

```
L0  Board      fpga_top
                  └─ system
L1  SoC          ├─ cpu
                 ├─ bus_interconnect → address_decoder
                 ├─ memory_subsystem → instruction_memory | data_memory
                 └─ gpu → gpu_register
L2  CPU edge       cpu → instruction_fetch (I-BUS) | cpu_core (D-BUS)
L3  Datapath         cpu_core → cpu_decoder | cpu_datapath | branch_unit
L4  Storage          cpu_datapath → cpu_register | status_register
L5  ALU unit         cpu_datapath → alu → arithmetic | logic_unit | shifter | comparator
L6  Bit ops          1-bit adder · shift-add multiply · restoring divide · serial compare · bit logic
-1  Foundation       packages: opcode_pkg → cpu_pkg → memory_pkg → bus_pkg / gpu_pkg ; alu_pkg
```

The layers below `cpu` are pure *combinational wiring plus small FSMs*; the only
sequential elements are the register file, the status register, the program
counter, the fetch buffer, the ALU sub-unit shift registers, and the
data-memory response pipeline.

Full instantiation tree (file paths in [Appendix D](#appendix-d--module-tree)):

```
fpga_top  (src/rtl/soc/fpga_top.sv)
└─ system  (src/rtl/soc/system.sv)
   ├─ u_cpu : cpu
   │  ├─ u_instruction_fetch : instruction_fetch
   │  │  └─ u_program_counter : program_counter
   │  └─ u_cpu_core : cpu_core
   │     ├─ u_cpu_decoder : cpu_decoder
   │     ├─ u_cpu_datapath : cpu_datapath
   │     │  ├─ u_cpu_register : cpu_register
   │     │  ├─ u_alu : alu
   │     │  │  ├─ u_arithmetic : arithmetic
   │     │  │  ├─ u_logic_unit : logic_unit
   │     │  │  ├─ u_shifter : shifter
   │     │  │  └─ u_comparator : comparator
   │     │  └─ u_status_register : status_register
   │     └─ u_branch_unit : branch_unit
   ├─ u_bus_interconnect : bus_interconnect
   │  └─ u_address_decoder : address_decoder
   ├─ u_memory : memory_subsystem
   │  ├─ u_instruction_memory : instruction_memory
   │  └─ u_data_memory : data_memory
   └─ u_gpu : gpu
      └─ u_gpu_register : gpu_register
```

---

## 4. Foundation: The Packages

Everything in LACOODA is typed by a small set of packages. They are the
"single source of truth" and carry a strict dependency order:

```
opcode_pkg  (no dependencies)
    ↓
cpu_pkg     (imports opcode_pkg; NEVER imports memory_pkg)
    ↓
memory_pkg  (uses cpu_pkg::WORD_BYTES)
    ↓
bus_pkg     (uses cpu_pkg + memory_pkg)      gpu_pkg (uses cpu_pkg + bus_pkg + memory_pkg)
                                             alu_pkg (uses cpu_pkg)
```

The dependency arrow is deliberately one-way to avoid circular package imports:
`cpu_pkg` must never depend on `memory_pkg`, so memory sizes live in
`memory_pkg`, not `cpu_pkg`.

### 4.1 `opcode_pkg` — `src/rtl/packages/opcode_pkg.sv`

Owns the opcode field width, the complete opcode map, and the classification
helpers. It has **no dependencies**, so any module can import it.

* `localparam int OPCODE_WIDTH = 6;`
* `typedef enum logic [5:0] { ... } opcode_e;` with the full map:

| Range | Meaning | Examples |
| --- | --- | --- |
| `0x00–0x09` | Arithmetic add/sub/mul/div/mod | `ALU_ADD=0x00`, `ALU_SUB=0x02`, `ALU_MUL=0x04`, `ALU_MODS=0x09` |
| `0x0A–0x0D` | Min/Max | `ALU_MINU=0x0A`, `ALU_MAXS=0x0D` |
| `0x0E–0x0F` | Unary arithmetic | `ALU_ABS=0x0E`, `ALU_NEG=0x0F` |
| `0x10–0x18` | Bitwise logic + pass | `ALU_NOT=0x10`, `ALU_AND=0x11`, `ALU_PASS_A=0x17`, `ALU_PASS_B=0x18` |
| `0x19–0x1D` | Shifts/rotates | `ALU_SHL=0x19`, `ALU_SHR=0x1A`, `ALU_SAR=0x1B`, `ALU_ROL=0x1C`, `ALU_ROR=0x1D` |
| `0x1E–0x27` | Comparisons | `ALU_EQ=0x1E`, `ALU_LTU=0x20`, `ALU_GES=0x27` |
| `0x28–0x2E` | Control flow | `CTRL_JMP=0x28`, `CTRL_BEQ=0x29`, …, `CTRL_BGEU=0x2E` |
| `0x2F–0x30` | Memory | `MEM_LOAD=0x2F`, `MEM_STORE=0x30` |

* `typedef logic [5:0] opcode_t;` — the raw field type used on ports/structs.
* `ALU_OPCODE_COUNT = int'(ALU_GES) + 1;` — encodings the ALU executes.
* Classification helpers (take raw bits so call sites stay cast-free):
  `is_valid_opcode`, `is_alu_opcode`, `is_unary_opcode`, `is_mov_op`,
  `is_movi_op`, `is_branch_opcode`, `is_memory_opcode`.

### 4.2 `cpu_pkg` — `src/rtl/packages/cpu_pkg.sv`

The architectural contract. Owns the word width, register-file geometry, STATUS
representation, instruction layout, and the instruction encoders.

**Word and types**

* `WORD_WIDTH = 32`, `WORD_BYTES = 4`.
* `typedef logic [31:0] word_t;`
* `typedef word_t instruction_t;` — one instruction = one architectural word.

**Register file**

* `REG_FILE_COUNT = 64`, `REG_FILE_ADDR_WIDTH = $clog2(64) = 6`.
* `typedef logic [5:0] reg_addr_t;`
* `ZERO_REG = '0` — R0 is architecturally hardwired to zero.

**STATUS / flags**

* `STATUS_WIDTH = 32`; `typedef logic [31:0] status_t;`
* `typedef struct packed { logic Z; logic N; logic C; logic V; logic DZ; } flags_s;`
* Implemented STATUS bits: `[4]=DZ`, `[3]=V`, `[2]=C`, `[1]=N`, `[0]=Z`; bits
  `[31:5]` reserved.
* `function make_flags(z, n, c, v, dz)` builds a `flags_s`.

**Instruction layout** (LSB first — this is the exact bit map used throughout):

```
[5:0]    RS2
[11:6]   RS1
[17:12]  RD
[23:18]  OPCODE
[24]     I   (immediate mode)
[25]     S   (update STATUS)
[31:26]  RESERVED
```

* `USED_INSTRUCTION_BITS = 26` (everything above must be zero for a legal
  instruction — enforced by `cpu_decoder`).
* **The immediate is NOT packed into the instruction.** Instructions that need
  one are followed by **one extra full word** (the *immediate word*).

**Struct overlay & immediate rule**

```systemverilog
typedef struct packed {
    logic      update_status;
    logic      immediate_mode;
    opcode_t   opcode;
    reg_addr_t rd;
    reg_addr_t rs1;
    reg_addr_t rs2;
} instruction_s;
```

* `uses_imm(opcode, immediate_mode)` is true for: any branch/jump, any
  LOAD/STORE, or any ALU op in immediate mode (`I=1`).
* `instr_uses_imm(instruction)` overlays an `instruction_t` onto
  `instruction_s` and calls `uses_imm`.

**Encoders** (used by testbenches and any future assembler):

* `encode_instruction(opcode, rd, rs1, rs2, immediate_mode, update_status)`
* `encode_branch(opcode, rs1, rs2)`
* `encode_jump()` — a `CTRL_JMP` with zero operands
* `encode_load(rd, base)` / `encode_store(source, base)`

**Validation** — `validate_configuration()` checks CPU-owned invariants only
(register count ≥ 2, opcode width large enough, instruction fields fit in
`WORD_WIDTH`). It deliberately does not check memory sizes.

### 4.3 `memory_pkg` — `src/rtl/packages/memory_pkg.sv`

Central source of truth for memory and MMIO **sizes** (not addresses).

* `INSTRUCTION_MEMORY_BYTES = 32 * 1024` (32 KiB) → `INSTRUCTION_MEMORY_COUNT`
  = 8192 words.
* `DATA_MEMORY_BYTES = 32 * 1024` (32 KiB) → `DATA_MEMORY_COUNT` = 8192 words.
* `GPU_MMIO_BYTES = 4 * 1024` (4 KiB) — the address space occupied by GPU
  registers. **Not framebuffer memory.**
* `PROGRAM_FILE = "src/programs/genesis_32.hex"`,
  `DATA_MEMORY_FILE = "src/programs/data_memory_32.hex"`.
* `validate_configuration()` — asserts sizes are positive and byte counts are
  divisible by `WORD_BYTES`.

Because the ROM/RAM images are loaded with `$readmemh` using **relative paths**,
simulations must be launched from the repository root (see `run.sh`).

### 4.4 `bus_pkg` — `src/rtl/packages/bus_pkg.sv`

Owns the bus protocol types and the absolute memory map.

```systemverilog
typedef enum logic { BUS_READ = 1'b0, BUS_WRITE = 1'b1 } bus_op_e;

typedef struct packed {
    logic    valid;
    bus_op_e op;
    word_t   addr;    // cpu_pkg::word_t
    word_t   wdata;
} bus_req_s;

typedef struct packed {
    logic  ready;
    word_t rdata;
} bus_rsp_s;
```

Memory-map constants (see [Appendix C](#appendix-c--address-map)):

* `DATA_MEMORY_BASE = 0`, `DATA_MEMORY_SIZE = DATA_MEMORY_COUNT * WORD_BYTES`,
  `DATA_MEMORY_LIMIT = 0x0000_8000`.
* `GPU_BASE = 0x1000_0000`, `GPU_SIZE = 0x0000_1000`,
  `GPU_LIMIT = 0x1000_1000`.
* `DDR3_BASE = 0x8000_0000`, `DDR3_SIZE = 0x0800_0000`,
  `DDR3_LIMIT = 0x8800_0000` — **reserves the intended future map only; it does
  not make DDR3 functional.**

### 4.5 `gpu_pkg` — `src/rtl/packages/gpu_pkg.sv`

Defines the GPU's local MMIO address type, register map, config/status structs,
and pixel format. The *absolute* base address is owned by `bus_pkg`; the GPU
only sees a **local** address after the interconnect subtracts `GPU_BASE`.

* `GPU_ADDR_WIDTH = $clog2(GPU_MMIO_BYTES) = 12`; `typedef logic [11:0] gpu_addr_t;`
* `typedef enum gpu_addr_t { ... } gpu_reg_addr_e;`:

| Register | Offset | Access |
| --- | --- | --- |
| `GPU_REG_ID` | `0x00` | Read-only (`GPU_ID_VALUE`) |
| `GPU_REG_CONTROL` | `0x04` | Read/Write |
| `GPU_REG_STATUS` | `0x08` | Read-only |
| `GPU_REG_FRAMEBUFFER_BASE` | `0x0C` | Read/Write |
| `GPU_REG_FRAMEBUFFER_WIDTH` | `0x10` | Read/Write |
| `GPU_REG_FRAMEBUFFER_HEIGHT` | `0x14` | Read/Write |
| `GPU_REG_CLEAR_COLOR` | `0x18` | Read/Write |

* Every register occupies one full 32-bit word (the bus has no byte enables).
* `GPU_ID_VALUE = 32'h4750_5530` (`"GPU0"` in ASCII).
* `gpu_config_s` = `{ control, framebuffer_base, framebuffer_width,
  framebuffer_height, clear_color }` — the CPU-writable, persistent state.
* `gpu_status_s` bit layout: `bit0 enabled`, `bit1 idle`, `bit2 busy`,
  `bit3 error`, `bit4 command_done`, `bit5 framebuffer_valid`,
  `bit6 display_active`, `[31:7] reserved`.
* Pixel format: `GPU_PIXEL_WIDTH = 32` (RGBA8888), `GPU_PIXEL_BYTES = 4`,
  `gpu_pixel_t`; coordinate `gpu_coord_t` is 16 bits wide.
* Internal (non-bus) structs `gpu_pixel_req_s`, `gpu_pixel_write_s`,
  `gpu_mem_req_s`, `gpu_mem_rsp_s` describe graphics-side operations.

### 4.6 `alu_pkg` — `src/rtl/packages/alu_pkg.sv`

Shared ALU constants and load-time helpers. It does **not** replace `cpu_pkg` or
`opcode_pkg`.

* `SERIAL_WIDTH = $clog2(WORD_WIDTH) = 5`.
* `MSB_ONE` = `32'h8000_0000`, `ALL_ONES` = `32'hFFFF_FFFF`.
* `typedef enum logic [1:0] { S_IDLE, S_RUN, S_DONE } alu_state_e;` — the shared
  sequencer state type for all four bit-serial sub-units.
* `rev(x)` — reverses a word (used to stream MSB-first).
* `twos_neg(x)` = `(~x) + 1` — two's-complement negation.

> **Note in the source:** the per-cycle serialiser steps (shift/rotate/push) are
> written *inline* in the sub-units rather than as package functions, because
> `iverilog` mis-schedules package-function calls used inside `always_comb`
> across multiple instances. The hot path therefore avoids them.

---

## 5. The Bus Contract

The same transaction protocol is used on the CPU instruction bus (I-BUS), the CPU
data bus (D-BUS), and inside the SoC. It is a simple **valid/ready** handshake:

```
Transaction completes when:  req.valid && rsp.ready
```

Rules:

* A request payload (`op`, `addr`, `wdata`) is held **stable** from assertion
  until `ready` — the master must not change it mid-transaction.
* `op` is one `bus_op_e`: `BUS_READ` or `BUS_WRITE`.
* Data is exactly **one `word_t` (32 bits)**. There are no byte-enable signals,
  which is why every MMIO register is word-granular.
* `valid` does not have to fall between back-to-back transactions; a new request
  may follow immediately in the next cycle.

### 5.1 `address_decoder` — `src/rtl/bus/address_decoder.sv`

Pure combinational range comparison on the global byte address:

```systemverilog
data_mem_sel = (addr >= DATA_MEMORY_BASE) && (addr < DATA_MEMORY_LIMIT); // [0x0, 0x8000)
gpu_mmio_sel = (addr >= GPU_BASE)        && (addr < GPU_LIMIT);          // [0x1000_0000, 0x1000_1000)
```

It produces two one-hot select signals and nothing else.

### 5.2 `bus_interconnect` — `src/rtl/bus/bus_interconnect.sv`

Routes the **single CPU D-BUS master** to one of two slaves and muxes the
response back.

* Instantiates `address_decoder`.
* **Data-memory request**: `valid = dbus_req.valid && data_mem_sel`,
  `addr = dbus_req.addr - DATA_MEMORY_BASE` (global → memory-local byte address).
* **GPU request**: `valid = dbus_req.valid && gpu_mmio_sel`,
  `addr = dbus_req.addr - GPU_BASE` (e.g. `0x1000_0020 - 0x1000_0000 = 0x20`).
* **Response mux**: passes through the selected slave's `bus_rsp_s`; for an
  **unmapped** address it synthesizes `ready = 1, rdata = 0` (no bus fault) so
  the CPU can never hang on a bad address.

> There is currently **one bus master** and **no arbitration**. Adding a GPU/TPU
> master will require arbitration and extra master ports here.

---

## 6. Memory Subsystem

`memory_subsystem` (`src/rtl/memory/memory_subsystem.sv`) is the SoC's memory
container. It instantiates two **physically separate** memories so instruction
fetch never contends with local data access:

* `instruction_memory` — I-BUS slave (a read-only ROM).
* `data_memory` — memory-bus slave (read/write BRAM).

```systemverilog
module memory_subsystem (
    input  logic clk, rst,
    input  bus_pkg::bus_req_s ibus_req, output bus_pkg::bus_rsp_s ibus_rsp, // instruction ROM
    input  bus_pkg::bus_req_s mem_req,  output bus_pkg::bus_rsp_s mem_rsp    // data BRAM
);
```

### 6.1 `instruction_memory` — `src/rtl/memory/instruction_memory.sv`

An `8192 × 32` array loaded at elaboration by
`$readmemh(memory_pkg::PROGRAM_FILE, mem)`.

* `ibus_rsp = {ibus_req.valid, rdata}` → `ready` mirrors `valid` (zero wait
  states), and `rdata` is **combinational**.
* Alignment/range check: address must be word-aligned (`addr % WORD_BYTES == 0`)
  and `< INSTRUCTION_MEMORY_COUNT`. Misaligned/out-of-range reads return zero
  and still complete.
* Indexing: `mem[ibus_req.addr / WORD_BYTES]` (byte address → word index).

### 6.2 `data_memory` — `src/rtl/memory/data_memory.sv`

The local data RAM, inferred as FPGA block RAM. It is a memory-bus slave whose
timing is intentionally **synchronous**, so Gowin can infer BSRAM.

* Array: `8192 × 32` `word_t`, initialized by
  `$readmemh(memory_pkg::DATA_MEMORY_FILE, mem)`.
* **Range checking is not repeated here.** The interconnect already decided the
  address belongs to data memory; this module only checks **word alignment**
  (`addr % WORD_BYTES == 0`). Misaligned access → completes normally, reads zero,
  writes nothing.
* **The memory array is intentionally not reset.**
  A reset loop over thousands of words would prevent block-RAM inference and
  blow the Gowin synthesis loop limit; reset clears interface state only.
* Response pipeline: an internal `pending` flag generates `ready`.

LOAD / STORE timing (one response cycle, `ready == pending`):

```
LOAD                                   STORE
cyc N   mem_req.valid=1, ready=0        cyc N   mem_req.valid=1, ready=0
        addr presented                          addr+wdata presented
        (rising edge) capture mem[idx]          (rising edge) write mem[idx]
cyc N+1 ready=1, rdata=captured         cyc N+1 ready=1
        (CPU latches rdata)
```

The CPU holds its request stable while `ready` is low, and a new request may
immediately follow (valid need not fall between transactions).

---

## 7. CPU — Top to Bottom

### 7.1 `cpu` — `src/rtl/cpu/cpu.sv`

The CPU boundary. It contains everything needed to execute the ISA and exposes
**two typed bus-master ports**: an I-BUS (instruction fetch) and a D-BUS
(LOAD/STORE). Instruction memory and data memory live outside it.

Key internal glue:

```systemverilog
assign dbus_req.valid = dbus_valid;
assign dbus_req.op    = dbus_write ? bus_pkg::BUS_WRITE : bus_pkg::BUS_READ;
assign dbus_req.addr  = dbus_addr;
assign dbus_req.wdata = dbus_wdata;

assign core_enable = instruction_available && !rst;
assign retire       = instruction_available && !rst && (retire_valid || illegal_instr);
```

* `core_enable` gates the execution core: a *buffered* instruction is always
  allowed to finish even if `run` is de-asserted meanwhile (this also guarantees
  a waiting D-BUS request cannot be abandoned).
* `retire` is fed back to `instruction_fetch` to advance the PC. Illegal
  instructions `retire` too (they have no side effects) so the fetch unit cannot
  wedge at a bad `pc`.
* Instantiated children: `instruction_fetch` (`u_instruction_fetch`) and
  `cpu_core` (`u_cpu_core`). The `operand_a/operand_b/alu_result/flags/status`
  outputs are retained only for simulation/debug observation.

### 7.2 `instruction_fetch` — `src/rtl/cpu/fetch/instruction_fetch.sv`

Owns the PC and a **one-entry instruction buffer**, and is the I-BUS master.

* Instantiates `program_counter` (`u_program_counter`).
* I-BUS request: `ibus_req.op = BUS_READ`, `ibus_req.addr = (FETCH_IMM) ? pc +
  WORD_BYTES : pc`, `ibus_req.valid = (fetch_state != FETCH_IDLE)`.
* Fetch FSM:

| State | Behavior |
| --- | --- |
| `FETCH_IDLE` | If nothing is buffered, go to `FETCH_INSTR`. |
| `FETCH_INSTR` | Latch `ibus_rsp.rdata` as the instruction. If it `instr_uses_imm`, go to `FETCH_IMM`, else back to `FETCH_IDLE` and mark `instruction_available`. |
| `FETCH_IMM` | On `ibus_rsp.ready`, latch the immediate word, buffer it, mark `instruction_available`, go to `FETCH_IDLE`. |

* `has_imm = instruction_available && instr_uses_imm(instruction)` — tells the PC
  how many words the buffered instruction occupies.
* On `rst` **or** `retire`, the buffer is cleared (instruction/immediate = 0,
  `instruction_available = 0`).
* Once a fetch request has started, de-asserting `run` does **not** abandon it;
  `run` only controls whether the *next* instruction is fetched.

### 7.3 `program_counter` — `src/rtl/cpu/fetch/program_counter.sv`

Byte-addressed, synchronous, active-high reset, priority = reset > redirect >
increment:

```systemverilog
if (rst)         pc <= '0;
else if (enable) pc <= redirect ? target
                                : pc + word_t'((has_imm ? 2 : 1) * WORD_BYTES);
```

* `enable` = `retire` (from `cpu`), so the PC only moves when an instruction
  completes.
* A 2-word increment **skips the immediate word** so it is never executed.
* A taken branch/jump loads `target` instead.

### 7.4 `cpu_core` — `src/rtl/cpu/core/cpu_core.sv`

The execution core: it decodes, runs the multi-cycle ALU, drives the D-BUS, and
reports completion. Children: `cpu_decoder`, `cpu_datapath`, `branch_unit`.

* `memory_op = memory_read_enable || memory_write_enable` (mutually exclusive by
  construction).
* Execution FSM (`ex_state`):

| State | Transition |
| --- | --- |
| `EX_IDLE` | If `core_enable && decode_valid`, pulse `alu_start` and go to `EX_ALU`. |
| `EX_ALU` | When `alu_done`, go to `EX_MEM` if `memory_op`, else back to `EX_IDLE`. |
| `EX_MEM` | When `mem_accept` (`dbus_valid && dbus_ready`) or `!core_enable`, go to `EX_IDLE`. |

* **D-BUS master** — the effective address is the ALU result (`ALU_ADD`):

```systemverilog
assign dbus_valid = (ex_state == EX_MEM) && core_enable && decode_valid && memory_op && !rst;
assign mem_accept = dbus_valid && dbus_ready;
assign dbus_write = memory_write_enable;
assign dbus_addr  = alu_result;      // base + signed byte offset
assign dbus_wdata = store_data;      // raw RS2
```

  Because `core_enable` stays asserted while the wrapper stalls the PC, the
  request payload is held stable until `dbus_ready`.
* **Retirement / writes** — a normal instruction completes when `alu_done`
  pulses; a LOAD/STORE additionally waits for the bus accept:

```systemverilog
assign retire_valid = core_enable && decode_valid && !rst &&
                      ( (!memory_op && alu_done) || mem_accept );
assign effective_register_write = register_write_enable && retire_valid;
assign effective_flags_write    = flags_write_enable    && retire_valid;
```

### 7.5 `cpu_decoder` — `src/rtl/cpu/core/cpu_decoder.sv`

Pure combinational decode. It overlays the instruction onto `instruction_s`
(`assign instr_fields = instruction;`) — **no hardcoded bit slicing** — and
classifies via the `opcode_pkg` helpers.

**Legality rules** (any violation → `illegal_instr = 1`, `decode_valid = 0`, all
outputs defaulted to safe values):

* Reserved bits must be zero: `(instruction >> USED_INSTRUCTION_BITS) != 0`.
* All three register fields must be `< REG_FILE_COUNT` (64).
* Valid opcode (`is_valid_opcode`).
* Per-format operand constraints:
  * **Branch/jump**: `rd == 0`, `I == 0`, `S == 0`; `CTRL_JMP` requires
    `rs1 == 0 && rs2 == 0`.
  * **LOAD**: `I == 0`, `S == 0`, `rs2 == 0` (rd = dest, rs1 = base).
  * **STORE**: `I == 0`, `S == 0`, `rd == 0` (rs1 = base, rs2 = source).
  * **MOV / unary**: `I == 0`, `rs2 == 0` (operand A = rs1).
  * **MOVI**: `I == 1`, `rs1 == 0`, `rs2 == 0` (operand B = immediate word).
  * **Binary immediate**: `rs2 == 0` (immediate word replaces RS2).
  * MOV/MOVI must not set `update_status`.

**Outputs for a legal instruction:**

* **Branch**: `branch_enable = 1`, `branch_op = opcode`, `branch_target =
  immediate_word`; rs1/rs2 feed the register file so the branch unit sees the
  real operand values.
* **Memory**: `rs1 = base`, `rs2`, `rd`; `alu_op = ALU_ADD`, `imm_sel = 1`,
  `imm_operand = immediate_word`; LOAD sets `memory_read_enable` +
  `register_write_enable`; STORE sets `memory_write_enable`; flags never written.
* **ALU**: `alu_op = opcode`, `imm_sel = immediate_mode`, `imm_operand =
  immediate_word`, `register_write_enable = 1`, `flags_write_enable =
  update_status`.

### 7.6 `cpu_datapath` — `src/rtl/cpu/core/cpu_datapath.sv`

Wires the register file, operand-B mux, ALU, writeback mux and status register.

* Write qualification: `register_wen = register_write_enable && alu_valid && !rst`
  (and the same for `flags_wen`) — an unrecognised encoding (`alu_valid` low) can
  never write.
* Register file exposes `operand_a` (RS1) and a raw `rs2_data` (RS2).
* **Operand-B mux**: `operand_b = imm_sel ? imm_operand : rs2_data`.
* **`store_data = rs2_data`** — the raw RS2 value, kept separate from
  `operand_b` because a STORE needs RS2 as write data while the ALU
  simultaneously needs the immediate as operand B (both to form the address).
* **Writeback mux**: `writeback_data = writeback_from_mem ? dmem_rdata :
  alu_result` (LOAD writes memory data; everything else writes the ALU result).
  The effective address remains visible on `alu_result` for LOAD/STORE.

### 7.7 `cpu_register` — `src/rtl/cpu/core/cpu_register.sv`

The register file: **64 × 32**, two asynchronous read ports, one synchronous
write port, asynchronous reset.

* R0 is hardwired to zero: reads of address 0 return `'0`; writes to address 0
  are ignored.
* `registers[idx] <= '0` for all entries on reset.

### 7.8 `status_register` — `src/rtl/cpu/core/status_register.sv`

Holds the ALU condition flags in a `flags_s` register and exposes them packed
into a `status_t`:

```systemverilog
assign status = status_t'({ flags_reg.DZ, flags_reg.V,
                            flags_reg.C,  flags_reg.N,  flags_reg.Z });
```

* Only `[4:0]` (`DZ,V,C,N,Z`) are stored; reserved high bits read as zero without
  storage.
* Updates only on `write_enable` (i.e. `flags_wen`); asynchronous clear on reset.

### 7.9 `branch_unit` — `src/rtl/cpu/core/branch_unit.sv`

Pure combinational control-flow decision, fed the two register operands and the
branch opcode:

| Opcode | Taken when |
| --- | --- |
| `CTRL_JMP` | always |
| `CTRL_BEQ` | `operand_a == operand_b` |
| `CTRL_BNE` | `operand_a != operand_b` |
| `CTRL_BLT` | `$signed(a) < $signed(b)` |
| `CTRL_BGE` | `$signed(a) >= $signed(b)` |
| `CTRL_BLTU` | `a < b` (unsigned) |
| `CTRL_BGEU` | `a >= b` (unsigned) |

On a taken condition it sets `redirect = 1` and `redirect_target = target`; the
PC loads the target on the next rising edge. When `enable` is low it returns
`redirect = 0` (but still forwards `target` for observation).

---

## 8. The ALU — Unit to Bit Operations

The ALU is **multi-cycle and bit-serial**: instead of a parallel adder/multiplier
tree, each operation is streamed one bit per clock through a handful of
flip-flops. This is the whole point of the design — a large, fast-but-expensive
combinational ALU was replaced by a small, single-adder machine.

`alu` (`src/rtl/cpu/alu/alu.sv`) is the dispatcher; four sub-units do the work.
All four share the `alu_pkg::alu_state_e` sequencer (`S_IDLE → S_RUN → S_DONE`)
and the `start / busy / done` contract.

### 8.1 `alu` — the dispatcher

* `valid = (op <= ALU_GES)` — the op is a recognised ALU encoding.
* Sub-unit selection (one-hot):

```systemverilog
sel_arith = (op <= ALU_MODS) || (op == ALU_ABS) || (op == ALU_NEG);          // 0x00–0x09, 0x0E, 0x0F
sel_logic = (op >= ALU_NOT) && (op <= ALU_PASS_B);                           // 0x10–0x18
sel_shift = (op >= ALU_SHL) && (op <= ALU_ROR);                              // 0x19–0x1D
sel_cmp   = ((op >= ALU_EQ) && (op <= ALU_GES)) ||
            ((op >= ALU_MINU) && (op <= ALU_MAXS));                          // 0x1E–0x27, 0x0A–0x0D
```

* Only the selected sub-unit receives `start`; the others stay idle.
* `busy` is the OR of all sub-unit busy flags; `done` is the OR of the done
  pulses plus `invalid_done` (an unrecognised opcode completes in one cycle with
  `result = 0`, `flags = 0`).
* **Flags are derived centrally** from the selected result: `Z = (result == 0)`
  and `N = result[31]` for every valid op; `C`, `V`, `DZ` come from the
  arithmetic sub-unit's side channels.

### 8.2 `arithmetic` — the 1-bit adder engine

One 1-bit full adder plus a carry flip-flop processes ADD/ADC/SUB/SBC/NEG/ABS,
one bit per clock (LSB first).

* Per-cycle 1-bit datapath:

```systemverilog
x_bit    = use_neg ? 1'b0 : a_bit;              // use_neg = NEG, or |a| of a negative ABS
y_bit    = use_neg ? ~a_bit : (b_bit ^ is_sub); // subtract = add of the complement
sum_bit  = x_bit ^ y_bit ^ carry_ff;
cout_bit = (x_bit & y_bit) | (carry_ff & (x_bit ^ y_bit));
```

* Carries preload (`ld_carry_ff`): `NEG → 1`, `ABS → sign(a)`, `SUB → 1`,
  `ADC/SBC → carry_in`, else `0`.
* **MUL/MULH** — iterative shift-add into a double-width accumulator
  (`macc <= b_bit ? macc + mcand : macc; mcand <= mcand << 1;`).
* **DIV/MOD** — restoring division: shift the dividend in MSB-first
  (`rev(...)`), subtract the divisor when the partial remainder is ≥ it, build
  the quotient one bit per cycle.
* **Signed special cases** avoid implementation-defined overflow:
  `MIN / -1` returns `MSB_ONE` for DIV and `0` for MOD.
* Side channels: `carry` (carry-out / no-borrow), `overflow` (signed overflow,
  set when the true result is not representable), `div_zero` (`operand_b == 0`).

### 8.3 `logic_unit` — one bit per clock

Two shift registers, a result register, and a **1-bit logic function**:

| Op | `out_bit` |
| --- | --- |
| `ALU_NOT` | `~a_bit` |
| `ALU_AND` | `a_bit & b_bit` |
| `ALU_OR` | `a_bit \| b_bit` |
| `ALU_XOR` | `a_bit ^ b_bit` |
| `ALU_NAND` | `~(a_bit & b_bit)` |
| `ALU_NOR` | `~(a_bit \| b_bit)` |
| `ALU_XNOR` | `~(a_bit ^ b_bit)` |
| `ALU_PASS_A` | `a_bit` (MOV) |
| `ALU_PASS_B` | `b_bit` (MOVI) |

Bitwise ops are bit-position independent, so LSB-first streaming is exact. This
is where MOV (`PASS_A`) and MOVI (`PASS_B`) are actually implemented.

### 8.4 `shifter` — hold, then stream

A single serial shifter covers SHL, SHR, SAR, ROL and ROR.

* SHL/SHR/SAR hold the serialiser for the first (shift-amount) cycles while
  emitting the fill bit, then stream the operand.
* SAR fill bit = `a_r[MSB]` (arithmetic sign extension); SHL/SHR fill = 0.
* Shift amount is capped at a full word width.
* Rotations pre-rotate a circular register into position (`rot_pre`) before
  emitting, so they take `WORD_WIDTH + offset` cycles.
* SHR/SAR stream **MSB-first** (`rev` on preload); SHL streams LSB-first.

### 8.5 `comparator` — first differing bit wins

Single MSB-first comparison: start `cmp_eq = 1`, and the first bit position where
the operands differ decides greater/less; all comparisons derive from that.

* Comparisons (`EQ, NE, LTU, LEU, GTU, GEU, LTS, LES, GTS, GES`) each output a
  1-bit boolean zero-extended to the word.
* **MIN/MAX** (`MINU/MAXU/MINS/MAXS`) reuse the same comparison and simply
  *select* `a` or `b` — no separate datapath.
* **Signed** variants are unsigned compares with the sign bit flipped (preload
  `cmp_a = a ^ MSB_ONE`, `cmp_b = b ^ MSB_ONE`).

### 8.6 Operation cycle cost

| Operation class | Cycles (approx.) |
| --- | --- |
| ADD/ADC/SUB/SBC/NEG/ABS | `WORD_WIDTH` (32) |
| AND/OR/XOR/NOT/NAND/NOR/XNOR/PASS_A/PASS_B | `WORD_WIDTH` (32) |
| MUL/MULH, DIV/MOD | `WORD_WIDTH` (32) |
| SHL/SHR/SAR | `WORD_WIDTH` (32) |
| ROL/ROR | `WORD_WIDTH + offset` (offset capped) |
| EQ/NE/LT*/LE*/GT*/GE*/MIN*/MAX* | `WORD_WIDTH` (32) |
| LOAD/STORE | ALU (address) + 1 bus-response cycle |
| Branch/jump | ALU runs, decision is combinational |

The ALU always runs for a decoded instruction (even branches/LOAD/STORE use it —
branches for an observable result, memory ops to form the effective address), so
a branch/load/store also takes ~32 cycles before it retires.

---

## 9. GPU (Wired Part)

Only the GPU's **CPU-visible MMIO register block** is wired today:
`gpu` → `gpu_register`. There is no rendering hardware in the live hierarchy
(see [Appendix F](#appendix-f--not-wired--reserved)).

### 9.1 `gpu` — `src/rtl/gpu/gpu.sv`

The GPU subsystem boundary. It exposes the same `bus_req_s`/`bus_rsp_s` slave
interface to the SoC and instantiates a single child, `gpu_register`.

There is no GPU execution core yet, so `gpu.sv` synthesizes the status word
inline:

```systemverilog
status      = '0;
status.enabled = gpu_cfg.control[0];
status.idle    = 1'b1;      // nothing is running
```

The remaining status bits (busy/error/command_done/display_active/
framebuffer_valid) read as zero. Future GPU components are meant to be added
*behind this boundary* without changing the SoC-facing bus interface.

### 9.2 `gpu_register` — `src/rtl/gpu/core/gpu_register.sv`

A direct **bus slave** implementing the MMIO register bank.

* The interconnect has already matched this address and subtracted `GPU_BASE`,
  so `mmio_req.addr` is a **GPU-local byte address**:
  `local_addr = gpu_addr_t'(mmio_req.addr)`.
* **Writes** (`valid && op == BUS_WRITE`) are decoded into `gpu_cfg`:

| Address | Register written |
| --- | --- |
| `GPU_REG_CONTROL` (`0x04`) | `gpu_cfg.control` |
| `GPU_REG_FRAMEBUFFER_BASE` (`0x0C`) | `gpu_cfg.framebuffer_base` |
| `GPU_REG_FRAMEBUFFER_WIDTH` (`0x10`) | `gpu_cfg.framebuffer_width` |
| `GPU_REG_FRAMEBUFFER_HEIGHT` (`0x14`) | `gpu_cfg.framebuffer_height` |
| `GPU_REG_CLEAR_COLOR` (`0x18`) | `gpu_cfg.clear_color` |

  `GPU_REG_ID` and `GPU_REG_STATUS` are read-only; unknown addresses ignore
  writes.
* **Reads** (`valid && op == BUS_READ`) return: `GPU_ID_VALUE` for `ID`,
  `status` for `STATUS`, the corresponding `gpu_cfg` field otherwise, and `0`
  for reserved addresses.
* `mmio_rsp.ready` is asserted for **every** valid request (MMIO has no wait
  states), with `rdata` computed combinationally — so a GPU access completes in
  a single cycle when the CPU asserts `dbus_valid`.

---

## 10. Board Top and Build

### 10.1 `fpga_top` — `src/rtl/soc/fpga_top.sv`

The synthesizable FPGA top. It maps the board pins onto `system`:

| Port | Direction | Meaning |
| --- | --- | --- |
| `clk27` | in | 27 MHz onboard oscillator — clocks the whole SoC |
| `btn_n0` | in | active-low button → synchronous active-high reset |
| `btn_n1` | in | active-low button → run enable |
| `led0` | out | `retire_valid` |
| `led1` | out | `illegal_instr` |
| `led2..led5` | out | reserved (driven `0`; "ALU parity not yet implemented") |

The buttons are asynchronous and active-low while the CPU reset is synchronous
and active-high, so a two-flop synchronizer de-metastabilizes and inverts both
pins in one place:

```systemverilog
always_ff @(posedge clk27) begin
    rst_sync <= {rst_sync[0], ~btn_n0};
    run_sync <= {run_sync[0], ~btn_n1};
end
assign rst = rst_sync[1];
assign run = run_sync[1];
```

`system` remains the unit under test in simulation; here it is driven by the
board pins and retirement status is exposed through the LEDs.

### 10.2 Constraints

* `src/constraints/sipeed_tang_primer_20k.cst` — pin locations:
  `clk27=H11`, `btn_n0=T10`, `btn_n1=T3`, LEDs `L16/L14/N14/N16/A13/C13`.
  The board's serial and DDR3 pins are present but **commented out** until those
  peripherals exist in RTL (unmatched port constraints fail PnR with CT1135).
* `src/constraints/sipeed_tang_primer_20k.sdc` — `create_clock -name clk27
  -period 37.037 -waveform {0.000 18.518} [get_ports {clk27}]` (27 MHz).

### 10.3 Memory images

`src/programs/` holds the `$readmemh` images. Each immediate is stored in the
word that follows its instruction. `genesis_32.hex` (the active
`PROGRAM_FILE`) is a small program whose first words decode as:

| Word (index) | Hex | Decodes to |
| --- | --- | --- |
| 0 | `01601000` | `MOVI R1, …` (`PASS_B`, rd=1, `I=1`) |
| 1 | `00000064` | immediate `100` |
| 2 | `01602000` | `MOVI R2, …` (rd=2, `I=1`) |
| 3 | `00000040` | immediate `64` |
| 4 | `00C00081` | `STORE R1,[R2+ …]` (`MEM_STORE`, rs1=2, rs2=1) |
| 5 | `00000008` | immediate `8` |

`data_memory_32.hex` is the 8192-word data RAM image (all zero in the shipped
tree). The `_64.hex` variants are legacy and are not referenced by
`memory_pkg`.

### 10.4 `run.sh`

The regression runner (`./run.sh`). It must be run **from the repository root**
so the relative `PROGRAM_FILE`/`DATA_MEMORY_FILE` paths resolve.

* Compiles each test with `iverilog -g2012 -Wall`, runs with `vvp`, and moves
  the produced VCD into `src/sim/waveforms/`.
* Test order (each its own top + source list):
  1. ALU (`alu_tb`)
  2. Register file (`cpu_register_tb`)
  3. Datapath (`cpu_datapath_tb`)
  4. Decoder (`cpu_decoder_tb`)
  5. CPU core (`cpu_core_tb`)
  6. Program counter / branch unit / instruction fetch (individual TBs)
  7. Data memory (`data_memory_tb`)
  8. Bus interconnect (`bus_interconnect_tb`)
  9. CPU I-BUS/D-BUS (`cpu_tb`)
  10. CPU system end-to-end (`system_tb`)
  11. GPU MMIO register (`gpu_tb`)
* Unless `--no-gui` is given it opens GTKWave on all waveforms. The legacy
  `--word32`/`--both` flags add `-DLACOODA_WORD_WIDTH` defines but the design is
  hard-locked to 32 bits (see [Appendix F](#appendix-f--not-wired--reserved)).

**Current status (verified):** `./run.sh --no-gui` runs the engine tests through
`branch_unit` cleanly, then **stops at the instruction-fetch test** with 4
failing checks (its `wait_for_buffered_pc`/immediate-buffer expectations), so
the later data-memory / interconnect / CPU / system / GPU tests are not reached
in a single run. This matches the note in `README.md` Appendix F. Run the
individual suites (or fix `instruction_fetch_tb.sv`) to exercise the tail of the
list.

### 10.5 Gowin project

`lacooda.gprj` lists the RTL sources, constraints, and hex images for the Gowin
IDE (device `GW2A-LV18PG256C8/I7`). Note it still lists the (empty)
`src/rtl/gpu/core/gpu_decoder.sv`. Synthesis/PnR outputs land under `impl/`
(git-ignored except the process-config JSON files).

### 10.6 Testbenches

| Testbench | DUT | Focus |
| --- | --- | --- |
| `cpu/alu_tb.sv` | `alu` | Every ALU op, flags, multi-cycle handshake |
| `cpu/register_file_tb.sv` | `cpu_register` | Read/write, R0 hardwired, reset |
| `cpu/datapath_tb.sv` | `cpu_datapath` | Operand mux, writeback, store_data |
| `cpu/decoder_tb.sv` | `cpu_decoder` | Legal/illegal encodings per format |
| `cpu/cpu_core_tb.sv` | `cpu_core` | Execution FSM, D-BUS, retire_valid |
| `cpu/program_counter_tb.sv` | `program_counter` | Increment/redirect/imm-skip |
| `cpu/branch_unit_tb.sv` | `branch_unit` | Each branch condition |
| `cpu/instruction_fetch_tb.sv` | `instruction_fetch` | Fetch FSM + buffering |
| `cpu/cpu_tb.sv` | `cpu` | I-BUS + D-BUS end-to-end |
| `memory/data_memory_tb.sv` | `data_memory` | Synchronous handshake, alignment |
| `bus/bus_interconnect_tb.sv` | `bus_interconnect` | Routing + response mux |
| `gpu/gpu_tb.sv` | `gpu` | MMIO read/write of all registers |
| `soc/cpu_system_tb.sv` | `system` | Full program: MOVI/STORE/LOAD/BEQ |

---

## 11. Reference Appendices

### Appendix A — Instruction Encoding Cheat-Sheet

One instruction word (LSB first):

```
 31        26 25 24 23      18 17    12 11   6 5    0
+------------+--+--+----------+--------+-------+------+
|  RESERVED  | S| I|  OPCODE  |   RD   |  RS1  | RS2  |
+------------+--+--+----------+--------+-------+------+
   6 bits      1  1    6          6        6      6
```

* `USED_INSTRUCTION_BITS = 26`; bits `[31:26]` must be 0.
* Immediate-taking instructions (branch/jump, LOAD/STORE, or `I=1` ALU) are
  followed by a **second full word**.

Worked examples (from `genesis_32.hex`):

| Hex | Fields | Meaning |
| --- | --- | --- |
| `0x01601000` | rs2=0, rs1=0, rd=1, opcode=0x18, I=1, S=0 | `MOVI R1, <imm>` |
| `0x01602000` | rd=2, opcode=0x18, I=1 | `MOVI R2, <imm>` |
| `0x00C00081` | rs2=1, rs1=2, rd=0, opcode=0x30 | `STORE R1, [R2 + imm]` |
| `encode_load(rd=3, base=2)` | opcode=0x2F, rs1=2, rd=3 | `LOAD R3, [R2 + imm]` |

### Appendix B — Opcode Table

| Opcode | Hex | Sub-unit / class | Writes flags | Operands |
| --- | --- | --- | --- | --- |
| `ALU_ADD` | 0x00 | arithmetic | if S | rd = rs1 + rs2/imm |
| `ALU_ADC` | 0x01 | arithmetic | if S | add with carry_in |
| `ALU_SUB` | 0x02 | arithmetic | if S | rd = rs1 - rs2/imm |
| `ALU_SBC` | 0x03 | arithmetic | if S | subtract with borrow |
| `ALU_MUL` | 0x04 | arithmetic | if S | low word of product |
| `ALU_MULH` | 0x05 | arithmetic | if S | high word of product |
| `ALU_DIVU` | 0x06 | arithmetic | if S | unsigned divide |
| `ALU_MODU` | 0x07 | arithmetic | if S | unsigned modulo |
| `ALU_DIVS` | 0x08 | arithmetic | if S | signed divide |
| `ALU_MODS` | 0x09 | arithmetic | if S | signed modulo |
| `ALU_MINU/MAXU/MINS/MAXS` | 0x0A–0x0D | comparator | if S | select min/max |
| `ALU_ABS` | 0x0E | arithmetic | if S | unary |
| `ALU_NEG` | 0x0F | arithmetic | if S | unary |
| `ALU_NOT` | 0x10 | logic | if S | unary |
| `ALU_AND/OR/XOR/NAND/NOR/XNOR` | 0x11–0x16 | logic | if S | binary |
| `ALU_PASS_A` | 0x17 | logic | never | `MOV rd, rs1` |
| `ALU_PASS_B` | 0x18 | logic | never | `MOVI rd, imm` (I=1) |
| `ALU_SHL/SHR/SAR/ROL/ROR` | 0x19–0x1D | shifter | if S | shift by rs2/imm |
| `ALU_EQ/NE/LTU/LEU/GTU/GEU/LTS/LES/GTS/GES` | 0x1E–0x27 | comparator | if S | boolean 0/1 |
| `CTRL_JMP` | 0x28 | branch unit | never | unconditional |
| `CTRL_BEQ/BNE/BLT/BGE/BLTU/BGEU` | 0x29–0x2E | branch unit | never | conditional |
| `MEM_LOAD` | 0x2F | memory | never | `rd = [rs1 + imm]` |
| `MEM_STORE` | 0x30 | memory | never | `[rs1 + imm] = rs2` |

* `S` = the instruction's `update_status` bit. MOV/MOVI/branch/memory never
  write flags (enforced by the decoder).
* Immediate-taking ALU ops set `I=1` and require `rs2 == 0`; the immediate word
  replaces RS2.

### Appendix C — Address Map

| Region | Base | Size | Limit (exclusive) | Owner |
| --- | --- | --- | --- | --- |
| Data RAM | `0x0000_0000` | 32 KiB (`0x8000`) | `0x0000_8000` | `data_memory` |
| GPU MMIO | `0x1000_0000` | 4 KiB (`0x1000`) | `0x1000_1000` | `gpu_register` |
| DDR3 (reserved) | `0x8000_0000` | 128 MiB (`0x0800_0000`) | `0x8800_0000` | *none — reserved only* |

Instruction memory is not in the CPU address space at all: it is a separate ROM
reachable only through the I-BUS.

### Appendix D — Module Tree

| Module | File | Instantiates |
| --- | --- | --- |
| `fpga_top` | `src/rtl/soc/fpga_top.sv` | `system` |
| `system` | `src/rtl/soc/system.sv` | `cpu`, `bus_interconnect`, `memory_subsystem`, `gpu` |
| `cpu` | `src/rtl/cpu/cpu.sv` | `instruction_fetch`, `cpu_core` |
| `instruction_fetch` | `src/rtl/cpu/fetch/instruction_fetch.sv` | `program_counter` |
| `program_counter` | `src/rtl/cpu/fetch/program_counter.sv` | — |
| `cpu_core` | `src/rtl/cpu/core/cpu_core.sv` | `cpu_decoder`, `cpu_datapath`, `branch_unit` |
| `cpu_decoder` | `src/rtl/cpu/core/cpu_decoder.sv` | — |
| `cpu_datapath` | `src/rtl/cpu/core/cpu_datapath.sv` | `cpu_register`, `alu`, `status_register` |
| `cpu_register` | `src/rtl/cpu/core/cpu_register.sv` | — |
| `status_register` | `src/rtl/cpu/core/status_register.sv` | — |
| `branch_unit` | `src/rtl/cpu/core/branch_unit.sv` | — |
| `alu` | `src/rtl/cpu/alu/alu.sv` | `arithmetic`, `logic_unit`, `shifter`, `comparator` |
| `arithmetic` | `src/rtl/cpu/alu/arithmetic.sv` | — |
| `logic_unit` | `src/rtl/cpu/alu/logic_unit.sv` | — |
| `shifter` | `src/rtl/cpu/alu/shifter.sv` | — |
| `comparator` | `src/rtl/cpu/alu/comparator.sv` | — |
| `bus_interconnect` | `src/rtl/bus/bus_interconnect.sv` | `address_decoder` |
| `address_decoder` | `src/rtl/bus/address_decoder.sv` | — |
| `memory_subsystem` | `src/rtl/memory/memory_subsystem.sv` | `instruction_memory`, `data_memory` |
| `instruction_memory` | `src/rtl/memory/instruction_memory.sv` | — |
| `data_memory` | `src/rtl/memory/data_memory.sv` | — |
| `gpu` | `src/rtl/gpu/gpu.sv` | `gpu_register` |
| `gpu_register` | `src/rtl/gpu/core/gpu_register.sv` | — |

### Appendix E — Glossary

| Term | Meaning |
| --- | --- |
| **word** | The 32-bit architectural unit (`cpu_pkg::word_t`). |
| **instruction word** | A `word_t` holding one encoded instruction. |
| **immediate word** | The full `word_t` that follows an immediate-taking instruction. |
| **immediate mode (`I`)** | Instruction bit that makes an ALU op use the immediate word as operand B. |
| **update status (`S`)** | Instruction bit that allows an ALU op to write the STATUS register. |
| **retire** | The single cycle in which an instruction completes; advances the PC and commits register/flags writes. |
| **redirect** | A taken branch/jump requesting the PC load `redirect_target`. |
| **effective address** | `RS1 + sign-extended immediate word`, computed as `ALU_ADD` for LOAD/STORE. |
| **I-BUS / D-BUS** | The CPU's instruction-fetch and load/store master buses. |
| **GPU-local address** | A byte address with `GPU_BASE` already subtracted by the interconnect. |
| **bit-serial** | Computing one bit per clock through a shared narrow datapath. |

### Appendix F — Not Wired / Reserved

These exist in the tree but are **not instantiated in the live hierarchy**. They
are listed here for orientation only:

* `src/rtl/gpu/core/gpu_core.sv` — a GPU status/config/validation module
  (framebuffer-valid logic, reserved `always_ff`). Not instantiated; `gpu.sv`
  currently produces status inline.
* `src/rtl/gpu/core/pixel_engine.sv` — row-major framebuffer address generation
  (`base + (y*width + x) * PIXEL_BYTES` with bounds check). Not instantiated.
* `src/rtl/memory/gpu_memory.sv` — a GPU-side **bus master** bridge
  (`gpu_mem_req_s` ↔ `bus_req_s`, one outstanding transaction). Not instantiated.
* `src/rtl/gpu/core/gpu_decoder.sv` — **empty file**; still referenced by
  `run.sh` and `lacooda.gprj`.
* **DDR3** — `bus_pkg` reserves `[0x8000_0000, 0x8800_0000)` but there is no DDR3
  controller; the region is unmapped and the `.cst` DDR3 pins are commented out.
* **`--word32` / `--both` and `_64.hex` files** — legacy from a parameterized
  era; `cpu_pkg::WORD_WIDTH` is now hard-locked to 32 and `memory_pkg` points at
  the `_32` images.
