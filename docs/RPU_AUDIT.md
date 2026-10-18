# LACOODA RPU — Audit and Architecture Specification

This document is the Phase 0 deliverable for the Routing Processing Unit. It
records what the repository actually contains, what the bus protocol actually
does, which hardware capabilities are real, and why the implemented RPU is the
right size for the Tang Primer 20K.

Nothing in this document assumes a module, memory port, or controller that is
not present in the tree.

---

## 1. Scope and toolchain

| Item | Actual value |
| --- | --- |
| Board | Sipeed Tang Primer 20K |
| FPGA | Gowin GW2A-18C (`GW2A-LV18PG256C8/I7`) |
| Board clock | 27 MHz onboard oscillator |
| Timing target | 100 MHz SDC / Gowin process configuration |
| Simulation | Icarus Verilog 12 (`-g2012 -Wall`) |
| Lint | Verilator 5.032 |
| Synthesis | Gowin IDE project `lacooda.gprj` |
| Gowin CLI in this environment | Not available; no synthesis/timing claim is made here |

---

## 2. Existing RTL inventory

### 2.1 Live hierarchy

| Module | Path | Role |
| --- | --- | --- |
| `fpga_top` | `src/rtl/soc/fpga_top.sv` | Pins, buttons, LEDs; wraps `system` |
| `system` | `src/rtl/soc/system.sv` | SoC integration; CPU, RPU, memory, GPU, DDR3 bridge |
| `cpu` | `src/rtl/cpu/cpu.sv` | CPU wrapper; I-BUS and D-BUS masters |
| `instruction_fetch` | `src/rtl/cpu/fetch/instruction_fetch.sv` | I-BUS master and fetch FSM |
| `program_counter` | `src/rtl/cpu/fetch/program_counter.sv` | PC |
| `cpu_core` | `src/rtl/cpu/core/cpu_core.sv` | Execution FSM |
| `cpu_decoder` | `src/rtl/cpu/core/cpu_decoder.sv` | Instruction decode |
| `cpu_datapath` | `src/rtl/cpu/core/cpu_datapath.sv` | Operand/writeback path |
| `cpu_register` | `src/rtl/cpu/core/cpu_register.sv` | 64 × 32-bit register file |
| `status_register` | `src/rtl/cpu/core/status_register.sv` | STATUS flags |
| `branch_unit` | `src/rtl/cpu/core/branch_unit.sv` | Branch decision |
| `alu` + sub-units | `src/rtl/cpu/alu/` | Bit-serial ALU |
| `instruction_rom` | `src/rtl/memory/instruction_rom.sv` | 32 KiB instruction ROM |
| `data_ram` | `src/rtl/memory/data_ram.sv` | 32 KiB data BRAM |
| `memory_subsystem` | `src/rtl/memory/memory_subsystem.sv` | ROM + RAM container |
| `gpu` | `src/rtl/gpu/gpu.sv` | GPU MMIO wrapper |
| `gpu_register` | `src/rtl/gpu/mmio/gpu_register.sv` | GPU register block |
| `ddr3_bridge` | `src/rtl/memory/ddr3_bridge.sv` | Native DDR3 bridge |
| `rpu_top` | `src/rtl/rpu/rpu_top.sv` | RPU SoC-facing wrapper |
| `rpu_crossbar` | `src/rtl/rpu/rpu_crossbar.sv` | 4 × 4 routing fabric |
| `rpu_slave_port` | `src/rtl/rpu/rpu_slave_port.sv` | Per-slave arbitration/response |
| `rpu_decoder` | `src/rtl/rpu/rpu_decoder.sv` | Master-qualified address decode |

### 2.2 Packages

| Package | Path | Owns |
| --- | --- | --- |
| `opcode_pkg` | `src/rtl/packages/opcode_pkg.sv` | Opcodes and classification |
| `cpu_pkg` | `src/rtl/packages/cpu_pkg.sv` | Word width, registers, instruction layout |
| `memory_pkg` | `src/rtl/packages/memory_pkg.sv` | ROM/RAM/GPU MMIO/DDR3 sizes |
| `bus_pkg` | `src/rtl/packages/bus_pkg.sv` | Bus protocol only |
| `gpu_pkg` | `src/rtl/packages/gpu_pkg.sv` | GPU register map and types |
| `alu_pkg` | `src/rtl/packages/alu_pkg.sv` | ALU constants |
| `rpu_pkg` | `src/rtl/rpu/rpu_pkg.sv` | RPU IDs, route map, capabilities |

### 2.3 Present but not wired

The following files exist but are **not instantiated** in the live hierarchy:

* `src/rtl/gpu/future/gpu_core.sv`
* `src/rtl/gpu/future/pixel_engine.sv`
* `src/rtl/gpu/future/gpu_bus_master.sv`

The GPU memory master port exists in the RPU and `system`, but no GPU engine
drives it. In `fpga_top` it is tied inactive.

---

## 3. Master inventory

| Master | Signals | Direction | Operation | Outstanding | Clock domain | Status |
| --- | --- | --- | --- | --- | --- | --- |
| CPU instruction fetch | `cpu_instr_bus_*` | CPU → RPU | Read only | 1 | `clk` | Implemented |
| CPU data | `cpu_bus_*` | CPU → RPU | Read/write + `wstrb` | 1 | `clk` | Implemented |
| GPU memory | `gpu_bus_*` | GPU → RPU | Read/write | 1 | `clk` | Port exists; engine absent; tied inactive |
| TPU memory | `tpu_bus_*` | TPU → RPU | Read/write | 1 | `clk` | Port exists; engine absent; tied inactive |
| DMA | — | — | — | — | — | No RTL; not connected |

The CPU instruction and data interfaces remain separate, as they were before the
RPU. Instruction fetch is not merged into the data port. It is a dedicated RPU
master whose route table entry permits only ROM.

---

## 4. Slave inventory and real capabilities

The capability model is also encoded in `rpu_pkg::rpu_slave_caps()` so tests can
check it rather than relying on prose.

| Slave | Signals | Address window | Storage | Read ports | Write ports | Shared slots | Max outstanding | Concurrent R/W | Response |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Instruction ROM | `rom_bus_*` | `[0x0, 0x8000)` | 8192 × 32 | 1 | 0 | 1 | 1 | No | Registered, next cycle |
| Data RAM | `ram_bus_*` | `[0x0, 0x8000)` | 8192 × 32 | 1 | 1 | 1 | 1 | No | Registered, next cycle |
| GPU MMIO | `gpu_mmio_bus_*` | `[0x1000_0000, 0x1000_1000)` | Registers | 1 | 1 | 1 | 1 | No | Combinational |
| DDR3 bridge | `ddr3_bus_*` | `[0x8000_0000, 0x8800_0000)` | External | 1 | 1 | 1 | 1 | No | Multi-cycle, backend-dependent |
| TPU MMIO | — | `[0x1000_1000, 0x1000_2000)` | None | 0 | 0 | 0 | 0 | No | Immediate error |
| DMA MMIO | — | `[0x1000_2000, 0x1000_3000)` | None | 0 | 0 | 0 | 0 | No | Immediate error |
| SD MMIO | — | `[0x1000_3000, 0x1000_4000)` | None | 0 | 0 | 0 | 0 | No | Immediate error |
| System MMIO | — | `[0x1000_4000, 0x1000_5000)` | None | 0 | 0 | 0 | 0 | No | Immediate error |

Important hardware facts:

* The data RAM has **one physical operation slot**. It supports byte writes but
  cannot perform a read and a write concurrently, nor two reads concurrently.
* The instruction ROM is a separate single-read memory. It is not a second port
  on the data RAM.
* The GPU MMIO block is combinational but has one register-access slot; writes
  require all four byte strobes, and unknown/partial accesses error.
* The DDR3 bridge accepts one outstanding transaction. Its completion time is
  backend-dependent. There is **no physical DDR3 controller** connected in this
  configuration; the bridge returns an error while `ddr3_backend_ready` is low.
* There is no dual-port or 2R1W memory in the current RTL. A capability-aware
  scheduler for such a memory is therefore not implemented, because there is no
  hardware for it to control.

---

## 5. Bus protocol and timing facts

The native protocol is defined by `bus_pkg`:

```systemverilog
typedef struct packed {
    logic      valid;
    bus_op_e   op;       // BUS_READ or BUS_WRITE
    word_t     addr;     // byte address, word-aligned
    word_t     wdata;
    bus_strb_t wstrb;    // one bit per byte
} bus_req_s;

typedef struct packed {
    logic  ready;        // transaction completed
    word_t rdata;
    logic  error;
} bus_rsp_s;
```

Rules:

* Completion occurs on a rising edge with `req.valid && rsp.ready`.
* Request fields must remain stable until completion.
* `rsp.ready` means **completion**, not request acceptance. The RPU never
  reinterprets it as a queue-accept signal.
* One outstanding transaction per master.
* Word width is 32 bits; `wstrb` enables individual bytes.
* No burst, transaction ID, write response, or cache attribute exists.
* All modules in the RPU path use the same `clk` and synchronous active-high
  reset. There is no clock-domain crossing in the RPU.
* CPU I-BUS is read-only. CPU D-BUS is read/write.
* `instruction_rom` and `data_ram` return registered responses one cycle after
  accepting a request.
* `gpu_register` returns a combinational response.
* `ddr3_bridge` is a multi-cycle FSM and requires `ddr3_backend_ready`.


---

## 6. Existing limitations that the RPU does not hide

* The data RAM is single-port, so same-slave read/write concurrency is
  physically impossible.
* No slave supports more than one outstanding transaction.
* No DMA, TPU, SD, or system MMIO peripheral exists yet. Their address windows
  are reserved and return deterministic bus errors.
* No physical DDR3 controller is integrated. The bridge is present; the backend
  is not.
* There is no timeout/recovery logic. A slave that never completes holds its
  slave port.
* Icarus Verilog 12 cannot elaborate unpacked-array parameters, 2D arrays, or
  array slices. The RPU therefore uses explicit 4 × 4 ports rather than a
  parameterized array fabric.

---

## 7. Retain, replace, introduce

| Action | Modules |
| --- | --- |
| Retain | `cpu`, fetch/core/ALU, `instruction_rom`, `data_ram`, `gpu`, `gpu_register`, `ddr3_bridge`, `system`, `fpga_top` |
| Replace | `bus_arbiter`, `bus_interconnect`, unused `address_decoder` |
| Introduce | `rpu_pkg`, `rpu_decoder`, `rpu_slave_port`, `rpu_crossbar`, `rpu_top` |
| Rewire | `system`, `memory_subsystem` (ROM/RAM slave ports) |
| Trim | `bus_pkg` (protocol only), `memory_pkg` (DDR3 capacity) |

---

## 8. Why per-destination arbitration, not global arbitration

| Option | Concurrency | Cost | Verdict |
| --- | --- | --- | --- |
| A. Global arbitration | One transaction through the whole SoC | Lowest | Rejected: unrelated destinations block each other |
| B. Per-destination arbitration | Independent destinations proceed in parallel | Moderate | **Chosen** |
| C. Capability-aware multiport crossbar | Adds same-slave port concurrency | High; needs real multiport RAM | Deferred: no multiport memory exists |

The implemented RPU is option B with a one-slot capability model per slave. It
maximizes concurrency against the hardware that actually exists:

* CPU→RAM, CPU_I→ROM, GPU→DDR3, and CPU→GPU MMIO use independent slave ports.
* A busy RAM does not block ROM, GPU MMIO, or DDR3.
* Same-slave requests are serialized by that slave's port only.
* No illegal read/write pair can be admitted because each slave port has one
  operation slot.

Option C would be justified only after a real dual-port or 2R1W memory is added.
At that point a new multi-port slave module and additional BSRAM would be
required; the current single-port RAM cannot be made multiport by adding RPU
logic alone.


---

## 9. Transaction state model

```text
REQUEST PRESENTED
        |
        v
DESTINATION DECODED
        |
        v
SLAVE PORT SLOT FREE?
   |               |
   NO             YES
   |               |
   v               v
MASTER HOLDS    ACCEPTED
REQUEST         (owner registered if not zero-wait)
   |               |
   +<-- retry      v
                AWAIT COMPLETION
                       |
                       v
                RESPONSE RETURNED
                       |
                       v
                   COMPLETED
```

The current protocol has no separate request-accept signal. A request is
"accepted" when its slave port selects it and forwards it downstream. If the
slave does not complete in that cycle, the port registers the owner and waits.
If the port is busy, the master simply keeps presenting the request; this is the
recommended master-held pending policy for the baseline RPU.

There is no request FIFO. This is deliberate: it minimizes registers and avoids
inventing an acceptance handshake that the native protocol does not have.

---

## 10. Phase status and acceptance evidence

| Phase | Status | Evidence |
| --- | --- | --- |
| 0 — Audit/spec | Complete | This document |
| 1 — Basic concurrent RPU | Complete | `rpu_crossbar_tb` parallel-routing and backpressure checks; full regression |
| 2 — Capability/port scheduling | Complete for existing single-port slaves | `rpu_slave_caps()` checks in `rpu_decoder_tb`; one-slot admission in `rpu_slave_port`; same-address collision test |
| 3 — Pending management | Complete | Master-held requests; DDR3 long-stall test proves ROM progresses |
| 4 — Integration | Complete | `system`/`memory_subsystem` rewired; old modules removed; full regression |
| 5 — Verification | Complete | Decoder 81 checks, slave port 26, crossbar 56, full regression `ALL TESTS PASSED` |
| 6 — Synthesis/optimization | Simulation/lint complete; Gowin synthesis not run here | Icarus compile clean; Verilator lint has no errors |
| 7 — Optional advanced features | Not implemented | Deliberate scope control |

### Acceptance criteria mapping

* **CPU→RAM, GPU→DDR3, TPU→MMIO independent:** covered by the four-way parallel
  test and the DDR3-stall/ROM-progress test.
* **Multiport slave reaches supported concurrency without illegal combinations:**
  the existing slaves have one slot, so the supported concurrency is one
  operation per slave. The capability model and same-address collision test
  enforce that no illegal pair is admitted. No multiport hardware exists to test.
* **DDR3 stall does not block RAM:** covered by the long-latency DDR3 test and
  the RAM/ROM backpressure test.
* **No dropped/duplicated/wrong-owner responses:** architectural invariants in
  `rpu_crossbar_tb` check routing uniqueness, per-slave response uniqueness, and
  per-master response uniqueness every clock edge.

---

## 11. Verification commands and actual results

```bash
cd /home/ifonlyloop/Documents/code/sysverilog/Lacooda
./run.sh --no-gui
```

Actual results in this environment:

* RPU decoder: 81/81 checks passed.
* RPU slave port: 26/26 checks passed.
* RPU crossbar: 56/56 checks passed.
* Full regression: exit 0, `ALL TESTS PASSED`.
* Verilator `--lint-only` on `rpu_top`: no errors; only pre-existing package
  warnings and unused-parameter warnings.
* Gowin synthesis/timing: **not measured** because the Gowin CLI is unavailable
  here.

### Resource estimate (estimate, not measurement)

| Resource | Estimate | Basis |
| --- | --- | --- |
| LUT | ~600–1,200 | Four decoders, 16 request muxes, four slave arbiters, four response muxes |
| FF | ~20–40 | Four slave ports × (priority 2 + owner 2 + state 1 + owner_valid 1) plus reset |
| BSRAM | 0 | The RPU contains no memory arrays |

These are order-of-magnitude estimates from the RTL structure. They are not
Gowin measurements. The CPU/ALU remains the dominant area consumer.

### Comparison with the old global arbiter

| Property | Old global arbiter + interconnect | RPU |
| --- | --- | --- |
| Transactions in flight | One through the whole data fabric | One per independent slave port |
| CPU→RAM vs GPU→DDR3 | Serialized by the global arbiter | Independent |
| Slow DDR3 | Could block every arbiter user | Only DDR3 requesters wait |
| Same-slave contention | Serialized | Serialized (hardware is single-port) |
| Area | Smaller | Larger: four slave ports and 16 request/response paths |
| Latency, zero-wait slave | Same combinational/registered behavior | Same |
| Latency, delayed slave | Owner retained until completion | Owner retained until completion |

The RPU trades additional routing and ownership logic for removal of
cross-destination head-of-line blocking. That is the intended trade-off for this
SoC.

---

## 12. Verdict

The baseline RPU is implemented and integrated. It satisfies the mandatory
concurrency rule for the hardware that actually exists: independent destinations
do not block each other, same-destination requests arbitrate fairly, responses
return only to their owner, and invalid/reserved/unaligned accesses terminate
deterministically.

It deliberately does **not** claim multiport memory concurrency, DDR3
outstanding-transaction concurrency, or DMA/TPU/SD functionality, because those
capabilities are not present in the current RTL. The capability model and the
extension checklists in `docs/RPU.md` define how to add them when the hardware
exists.
