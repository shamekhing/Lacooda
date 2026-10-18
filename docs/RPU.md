# LACOODA RPU — Routing Processing Unit

The RPU is LACOODA's SoC routing fabric. It replaces the former global
`bus_arbiter` + single-lane `bus_interconnect` + unused `address_decoder`
combination with a routing fabric that:

* decodes `(master, address)` into a destination slave and a slave-local address,
* arbitrates independently at each slave,
* routes requests across a 4 × 4 crossbar,
* returns each response only to the originating master,
* converts invalid, reserved, or unaligned accesses into immediate bus errors.

The native `bus_req_s` / `bus_rsp_s` protocol and the `valid && ready`
completion rule are unchanged.

The hardware audit, real capability facts, trade-off analysis, and phase
evidence are in [`docs/RPU_AUDIT.md`](RPU_AUDIT.md).

---

## 0. Slave capability model

The RPU is sized to the hardware that actually exists. `rpu_pkg::rpu_slave_caps()`
encodes the same facts that tests check.

| Slave | Read ports | Write ports | Operation slots | Outstanding | Concurrent R/W | Response |
| --- | --- | --- | --- | --- | --- | --- |
| ROM | 1 | 0 | 1 | 1 | No | registered, next cycle |
| DATA_RAM | 1 | 1 (shared) | 1 | 1 | No | registered, next cycle |
| GPU_MMIO | 1 | 1 (shared) | 1 | 1 | No | combinational |
| DDR3 bridge | 1 | 1 (shared) | 1 | 1 | No | multi-cycle |

`rpu_slave_port` therefore implements exactly one operation slot. It cannot
admit an illegal read/write pair, and a busy slave cannot block a different
slave. A real dual-port or 2R1W memory would require a new multi-port slave
module and additional block RAM; it is not claimed here.

---

## 1. Architecture

```
 CPU_I ──┐                         ┌── ROM
 CPU_D ──┤                         ├── DATA_RAM
 GPU   ──┼──> rpu_decoder ──> crossbar ──> GPU_MMIO
 TPU   ──┘     (4 routes)     (4 slave      DDR3
                               ports)
```

Each slave port contains its own round-robin arbiter and owner state. A
transaction to RAM and a transaction to DDR3 can therefore be in flight at the
same time. Masters targeting the same slave arbitrate; masters targeting
different slaves do not.

The RPU is a **fixed 4 × 4 fabric**. This is deliberate: the project simulator,
Icarus Verilog 12, cannot elaborate unpacked-array parameters, two-dimensional
arrays, or array slices. The fabric uses explicit named ports instead. The
routing policy is still centralized in `rpu_pkg.sv`.

---

## 2. File map

| File | Role |
| --- | --- |
| `src/rtl/rpu/rpu_pkg.sv` | Master/slave IDs, route result, memory-map constants, `rpu_decode()`, `rpu_validate_map()` |
| `src/rtl/rpu/rpu_decoder.sv` | One combinational decoder instance for all four masters |
| `src/rtl/rpu/rpu_slave_port.sv` | Per-slave round-robin arbiter, owner FSM, request mux, response demux |
| `src/rtl/rpu/rpu_crossbar.sv` | 4 × 4 request/response matrix, decoder wiring, error responses |
| `src/rtl/rpu/rpu_top.sv` | SoC-facing named wrapper |
| `src/rtl/soc/system.sv` | Instantiates `rpu_top` between CPU/GPU/TPU and memory/MMIO/DDR3 |
| `src/rtl/memory/memory_subsystem.sv` | Exposes ROM and RAM as separate RPU slaves |

---

## 3. Masters and slaves

### Masters

| ID | Port | Role | Permitted regions |
| --- | --- | --- | --- |
| `RPU_M_CPU_I` | `cpu_instr_bus_*` | CPU instruction fetch | ROM |
| `RPU_M_CPU_D` | `cpu_bus_*` | CPU loads/stores and MMIO | RAM, GPU MMIO, DDR3 |
| `RPU_M_GPU` | `gpu_bus_*` | GPU memory traffic | RAM, GPU MMIO, DDR3 |
| `RPU_M_TPU` | `tpu_bus_*` | TPU memory traffic | RAM, GPU MMIO, DDR3 |

The GPU MMIO block is a **slave**, not a master. The GPU memory interface is a
separate **master**. Do not merge them. The same distinction will apply to the
future TPU MMIO slave and TPU memory master.

### Slave ports

| Port | Slave | Purpose |
| --- | --- | --- |
| `s0` / `rom_bus_*` | `instruction_rom` | Instruction fetch |
| `s1` / `ram_bus_*` | `data_ram` | CPU/GPU/TPU data |
| `s2` / `gpu_mmio_bus_*` | `gpu_register` | GPU configuration/status |
| `s3` / `ddr3_bus_*` | `ddr3_bridge` | External DDR3 window |

---

## 4. Master-qualified routing

A route is selected by `(master, address)`, not by address alone. This preserves
the existing Harvard behaviour without changing the CPU or the boot program:

* CPU_I sees ROM at `0x0000_0000`.
* CPU_D/GPU/TPU see DATA_RAM at `0x0000_0000`.

The overlap is legal because the two views have disjoint permissions.
`rpu_validate_map()` therefore checks overlap **per master**, not globally.

### Route table

| Region | Base | Limit | Slave | Implemented | Masters |
| --- | --- | --- | --- | --- | --- |
| ROM | `0x0000_0000` | `0x0000_8000` | ROM | yes | CPU_I |
| DATA_RAM | `0x0000_0000` | `0x0000_8000` | DATA_RAM | yes | CPU_D, GPU, TPU |
| GPU_MMIO | `0x1000_0000` | `0x1000_1000` | GPU_MMIO | yes | CPU_D, GPU, TPU |
| TPU_MMIO | `0x1000_1000` | `0x1000_2000` | — | no | data masters |
| DMA_MMIO | `0x1000_2000` | `0x1000_3000` | — | no | data masters |
| SD_MMIO | `0x1000_3000` | `0x1000_4000` | — | no | data masters |
| SYSTEM_MMIO | `0x1000_4000` | `0x1000_5000` | — | no | data masters |
| DDR3 | `0x8000_0000` | `0x8800_0000` | DDR3 | yes | CPU_D, GPU, TPU |

Reserved regions are **mapped but unimplemented**. They return a bus error and
generate no slave traffic. This is different from an unmapped address, which
also returns a bus error but is reported as `mapped = 0` by the decoder.

### Local addresses

The decoder subtracts the region base:

```
local_addr = global_addr - region_base
```

The ROM and RAM bases are zero, so their local addresses equal the global
address. GPU MMIO and DDR3 are translated before reaching their slaves.

---

## 5. Transaction lifecycle

1. A master asserts `req.valid` and holds `op/addr/wdata/wstrb` stable.
2. `rpu_decoder` produces `{valid, mapped, slave, local_addr}` for all four
   masters in one combinational instance.
3. The crossbar drives the request into the selected slave port. The other
   three slave inputs for that master remain zero.
4. The slave port's round-robin arbiter selects one requester when idle:
   * if the slave asserts `ready` in the same cycle, the transaction completes
     on the next rising edge and priority rotates immediately;
   * otherwise the port stores the owner and waits in `SP_ACTIVE`.
5. The slave response is forwarded only to the selected/owner master. All other
   masters see `ready = 0`.
6. On `req.valid && rsp.ready`, the slave port rotates priority, clears the
   owner, and returns to idle.

No request buffering, pipelining, bursts, or multiple outstanding transactions
are implemented. Each master has at most one transaction in flight, matching the
existing bus contract.

---

## 6. Arbitration and fairness

Each slave port uses the same policy as the former `bus_arbiter`:

* `priority_reg` rotates after every completed transaction.
* In `SP_IDLE`, the port scans from `priority_reg` and selects the first valid
  request.
* In `SP_ACTIVE`, only the registered owner is selected, regardless of other
  requests.
* A continuously requesting master cannot starve another master as long as the
  downstream slave eventually completes.

A slave that never asserts `ready` holds its port in `SP_ACTIVE` indefinitely.
Per-slave timeouts are a future extension.

---

## 7. Error semantics

The RPU returns an immediate error response when:

* the address is not word-aligned,
* the address is outside every declared region (`mapped = 0`),
* the address is inside a reserved region (`mapped = 1`, `valid = 0`).

The error response is:

```systemverilog
ready = 1'b1;
error = 1'b1;
rdata = '0;
```

It is generated combinationally and completes on the next rising edge. No slave
request is issued. This matches the former interconnect's behaviour for
unmapped accesses and prevents the CPU from hanging on a bad address.

---

## 8. Adding a master

The fabric is fixed at four masters. To add a fifth master (for example DMA):

1. Add an identifier to `rpu_master_e` in `rpu_pkg.sv` and update
   `RPU_MASTERS` / `RPU_MASTER_ID_W`.
2. Extend the permission mask constants and the `rpu_decode()` case statement.
3. Add a fifth request/response pair to each `rpu_slave_port` instance and to
   the arbitration `case` blocks.
4. Add the master's request/response ports to `rpu_crossbar.sv` and a named
   pair to `rpu_top.sv`.
5. Add the master's request matrix block and response multiplexer in
   `rpu_crossbar.sv`.
6. Connect the master in `system.sv`.
7. Extend `rpu_decoder.sv` with the new address input and route output.
8. Add tests for its permitted and rejected regions.

The `rpu_validate_map()` function and the decoder testbench should be updated in
the same change.

---

## 9. Adding a slave

1. Add an identifier to `rpu_slave_e` and keep it below `RPU_SLAVES`; increment
   `RPU_SLAVES`.
2. Add the region constants to `rpu_pkg.sv` and a branch in `rpu_decode()`.
3. Add a `rpu_slave_port` instance in `rpu_crossbar.sv`: four request inputs,
   four response outputs, one downstream request/response pair.
4. Add four request signals, four response signals, and a request-matrix block
   for the new slave.
5. Add the new slave to the response multiplexers in `rpu_crossbar.sv`.
6. Add the slave ports to `rpu_top.sv` and connect them in `system.sv`.
7. Extend the testbenches with a routing case, a contention case, and an error
   case for the new slave.

Do not forget the local-address translation: the new slave receives
`global_addr - region_base`.

---

## 10. Verification

| Testbench | Coverage |
| --- | --- |
| `rpu_decoder_tb` | Map validation, all region boundaries, master masks, reserved regions, local translation, agreement with `rpu_pkg::rpu_decode()` |
| `rpu_slave_port_tb` | Round-robin, owner stability, immediate/delayed responses, response isolation, reset |
| `rpu_crossbar_tb` | Four-way parallel routing, same-slave round-robin, same-address read/write collision, unmapped/reserved/unaligned errors, long-latency DDR3, backpressure isolation, reset with outstanding, response-ownership invariants |
| `cpu_system_tb` | Boot program executed through the RPU; CPU_I fetch and CPU_D load/store |

Run the full regression with:

```
./run.sh --no-gui
```

---

## 11. Timing and resource notes

The RPU is combinational except for the per-slave priority/owner registers. It
adds approximately the same combinational depth as the former arbiter plus
interconnect: decode → per-slave arbitration → slave request, and slave response
→ response multiplexer.

If timing becomes critical on the GW2A-18C:

* replace the two-comparator range checks with mask compares on the high address
  bits;
* keep the per-slave arbiter shallow (four masters);
* add a register slice only if the synthesis report shows the RPU on the
  critical path.

The RPU itself does not add a clock-domain crossing. All masters and slaves must
share the SoC clock.

---

## 12. Future extensions

* Per-slave timeout counters that return an error instead of blocking forever.
* Performance counters: transactions and errors per master/slave.
* QoS or weighted arbitration.
* Burst support and multiple outstanding transactions (requires transaction IDs
  and per-slave tag tracking).
* A programmable route table exposed through system MMIO.
* Clock-domain crossing for slow peripherals.
* A packet-switched NoC version for larger accelerator clusters.

These are deliberately outside the current RPU. The fabric boundary and the
`bus_req_s` / `bus_rsp_s` protocol are designed so they can be added without
changing the CPU or the existing slaves.
