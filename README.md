# Build a CPU by Hand with SystemVerilog

## The Development Journey 

**Project:** LACOODA\
**Language:** SystemVerilog\
**Target direction:** FPGA(N/A)\
**CPU datapath:** 64-bit by default\
**Instruction word:** 64-bit by default\
**Register file:** 64 × 64-bit by default\
**Purpose:** A hands-on learning manual reconstructed from my stupid questions to AI.

------------------------------------------------------------------------

# Preface

This is not a SystemVerilog tutorial nor a standard README but mostly my learning journey to build game from hardware from scratch.

The goal is to learn SystemVerilog by building a processor, discovering
the places where a software-programming mental model stops working, and
then progressively turning a collection of arithmetic modules into a CPU
with instructions, state, program flow, memory, a handshake bus, and a
clean system boundary.

The processor is **LACOODA**. from the 3 hump lacooda ygo card but it is a long story so i will save you the details.

The order matters. We do not begin with a complete CPU diagram and
pretend every block is already obvious. We begin with the exact
questions that arise when the first modules are connected:

-   Is SystemVerilog executed from top to bottom?
-   Which module runs first?
-   What is the difference between a port and a signal?
-   If the decoder and datapath are active simultaneously, how can
    decoding happen "before" execution?
-   Why does `assign fields = instruction;` work?
-   Why does a register write need a clock but an ALU result does not?
-   What is the difference between a conceptual CPU stage and a pipeline
    stage?
-   Why can internal CPU wiring work without `valid/ready`, while
    external memory needs a handshake?
-   What does it mean for an instruction to retire?
-   Why can `777` become `9`?
-   How can a huge memory map accidentally become zero?
-   What does simulation prove, and what does only synthesis/timing
    analysis prove?

Those are not side questions. They are part of the curriculum.

The finished CPU boundary developed in this journey exposes two external
master interfaces:

``` text
                 +----------------------+
                 |     LACOODA CPU      |
                 |                      |
                 | PC / fetch buffer    |
                 | decoder              |
                 | register file        |
                 | ALU / datapath       |
                 | status flags         |
                 | branch unit          |
                 | LOAD / STORE control |
                 +----------+-----------+
                            |
                    +-------+-------+
                    |               |
                  I-BUS           D-BUS
                    |               |
====================|===============|================ CPU boundary
                    |               |
             instruction      bus/interconnect
                memory              |
                                  data
                                  memory
```

Everything beyond that boundary---DDR3, MMIO, controllers, GPU, HDMI,
audio---is a system concern rather than something that should be hidden
inside `cpu.sv`.

------------------------------------------------------------------------

# How to Use This Manual

Each major part uses the same learning pattern:

1.  **Mental model** --- what hardware idea is being introduced.
2.  **SystemVerilog mechanism** --- the language feature used to
    describe it.
3.  **LACOODA implementation** --- how the real processor uses it.
4.  **Understanding gap** --- a misconception worth confronting
    directly.
5.  **Experiment** --- something to modify or inspect.
6.  **Verification** --- what the testbench must prove.
7.  **Exit condition** --- what should be understood before continuing.

The manual follows the development journey rather than reorganizing
everything into a conventional university syllabus.

------------------------------------------------------------------------

# Part I --- Stop Thinking Like a Software Interpreter

## 1. SystemVerilog Describes Hardware

A C++ statement usually describes an operation that executes after a
previous operation.

``` cpp
a = b + c;
d = a ^ e;
```

The natural software interpretation is:

1.  calculate `a`,
2.  then calculate `d`.

A continuous SystemVerilog description is different:

``` systemverilog
assign a = b + c;
assign d = a ^ e;
```

These describe two pieces of hardware that exist at the same time.

There is an adder driving `a`. There is XOR logic consuming `a` and `e`
and driving `d`.

The dependency still matters:

``` text
b ----\
       ADD ---- a ----\
c ----/                XOR ---- d
e --------------------/
```

But the dependency is not created because the first `assign` appears
earlier in the file. It is created by the wiring.

### Understanding gap: "Which one executes first?"

For combinational hardware, that is usually the wrong question.

The better question is:

> What signals depend on what other signals?

When `b` changes, the adder output eventually changes. That change
propagates to the XOR input. The XOR output then settles. Simulation
models this propagation according to SystemVerilog semantics; physical
FPGA logic has actual propagation delays.

Source-code order is not the CPU execution order.

------------------------------------------------------------------------

## 2. Modules Are Hardware Blocks

A module defines a hardware block and its connection points.

``` systemverilog
module example (
    input  logic a,
    input  logic b,
    output logic y
);

    assign y = a & b;

endmodule
```

The ports are the block's boundary.

``` text
a ----> +---------+
        | example | ----> y
b ----> +---------+
```

When a parent module instantiates it:

``` systemverilog
logic left;
logic right;
logic result;

example u_example (
    .a(left),
    .b(right),
    .y(result)
);
```

the left-hand names in `.a(left)` and `.b(right)` are **child ports**.
The right-hand names are **signals in the parent**.

### Understanding gap: port vs signal

Think of:

``` systemverilog
.a(left)
```

as:

``` text
child connection point "a"
          |
          +---- parent wire "left"
```

A port is not "the data." It is an interface point through which a
signal is connected.

------------------------------------------------------------------------

## 3. One Parent Signal Can Connect Multiple Blocks

This became important when connecting the LACOODA decoder to the
datapath.

``` systemverilog
logic [5:0] decoded_op;

decoder u_decoder (
    .alu_op(decoded_op)
);

datapath u_datapath (
    .alu_op(decoded_op)
);
```

No extra:

``` systemverilog
assign ...
```

is required between those instances.

The signal `decoded_op` is already the connection.

Conceptually:

``` text
                  decoded_op
decoder output -------------------- datapath input
```

### Driver rule

The important question is not how many modules see a signal.

The important question is how many things **drive** it.

A single driver can feed many consumers. Multiple conflicting drivers
are usually a design error unless the signal is intentionally resolved.

------------------------------------------------------------------------

## 4. Combinational vs Sequential Hardware

Two categories dominate this CPU.

### Combinational

Examples:

-   decoder logic,
-   ALU,
-   comparisons,
-   muxes,
-   address calculations.

Typical constructs:

``` systemverilog
assign ...
```

or:

``` systemverilog
always_comb begin
    ...
end
```

The output responds to the current input values.

### Sequential

Examples:

-   program counter,
-   general-purpose registers,
-   status register,
-   instruction buffer.

Typical construct:

``` systemverilog
always_ff @(posedge clk) begin
    ...
end
```

State changes at a clock edge.

### Mental model

During a cycle:

``` text
stored state
    |
    v
combinational logic settles
    |
    v
next values become ready
    |
    v
posedge clk
    |
    v
new state is captured
```

This single model explains most of the CPU.

------------------------------------------------------------------------

# Part II --- The SystemVerilog Needed for LACOODA

## 5. Packed Vectors

A 64-bit value:

``` systemverilog
logic [63:0] value;
```

Bit 63 is the most significant bit. Bit 0 is the least significant bit.

Slices:

``` systemverilog
value[31:0]
value[63:32]
```

A CPU is full of packed bit vectors because registers, instructions,
addresses, flags, and opcodes all have exact widths.

------------------------------------------------------------------------

## 6. Concatenation

Curly braces concatenate fields:

``` systemverilog
{a, b}
```

If `a` is 8 bits and `b` is 8 bits, the result is 16 bits:

``` text
[ a ][ b ]
```

This is central to instruction encoding and extension operations.

------------------------------------------------------------------------

## 7. Replication

SystemVerilog can repeat a bit pattern:

``` systemverilog
{4{1'b1}}
```

produces:

``` text
1111
```

This explains the sign-extension expression that caused confusion during
development:

``` systemverilog
return {
    {(DATA_WIDTH-IMMEDIATE_WIDTH){value[IMMEDIATE_WIDTH-1]}},
    value
};
```

Read it from inside out.

First:

``` systemverilog
value[IMMEDIATE_WIDTH-1]
```

is the immediate's sign bit.

Then:

``` systemverilog
{(DATA_WIDTH-IMMEDIATE_WIDTH){sign_bit}}
```

repeats that sign bit enough times to fill the upper part of the
destination.

Finally:

``` systemverilog
{ repeated_sign_bits, value }
```

concatenates the extension and original immediate.

For a 32-bit immediate extended to 64 bits:

``` text
negative immediate:

bit 31 = 1

11111111111111111111111111111111 | original 32 bits
<----------- 32 bits ----------->   <--- 32 bits --->
```

------------------------------------------------------------------------

## 8. Types and `typedef`

Instead of spreading raw widths everywhere:

``` systemverilog
logic [63:0]
logic [5:0]
logic [31:0]
```

LACOODA defines architectural types.

Conceptually:

``` systemverilog
typedef logic [DATA_WIDTH-1:0] data_t;
typedef logic [REG_ADDR_WIDTH-1:0] reg_addr_t;
typedef logic [IMMEDIATE_WIDTH-1:0] imm_t;
typedef logic [INSTRUCTION_WIDTH-1:0] instruction_t;
```

This matters because architecture changes should propagate from root
parameters.

------------------------------------------------------------------------

## 9. Casting

A sized architectural cast:

``` systemverilog
data_t'(100)
```

means:

> represent this value using the width and signedness rules of `data_t`.

Likewise:

``` systemverilog
imm_t'(777)
```

does **not** promise that 777 fits.

If:

``` text
IMMEDIATE_WIDTH = 8
```

then:

``` text
777 decimal = 0x309
8-bit field keeps 0x09
0x09 = 9
```

This exact issue later exposed a parameterized testbench bug.

------------------------------------------------------------------------

## 10. Packages

LACOODA separates shared architectural definitions into packages.

The important conceptual split became:

``` text
alu_pkg
  |
  +-- ALU opcode definitions
  +-- flag type
  +-- ALU-related shared definitions

cpu_pkg
  |
  +-- data width
  +-- register count
  +-- instruction width
  +-- immediate width
  +-- instruction fields
  +-- encoders/helpers
  +-- CPU-wide architectural types

bus_pkg
  |
  +-- system-side address map
  +-- bus mapping constants
```

The CPU should not duplicate the same architectural number in ten files.

------------------------------------------------------------------------

# Part III --- Stage 1: Build the ALU

## 11. Why Start with the ALU?

The ALU is a good first subsystem because it is mostly combinational.

Inputs:

``` text
operand A
operand B
operation
carry input
```

Outputs:

``` text
result
flags
validity/status
```

The first LACOODA stage implemented a broad 64-bit ALU instruction set,
including arithmetic, signed operations, logic, shifts, rotations,
comparisons, pass-through operations, and status flags.

The development regression reached **134/134 ALU checks passing**.

------------------------------------------------------------------------

## 12. Split the ALU into Functional Units

Instead of one giant expression, LACOODA was organized into functional
blocks:

``` text
                    +----------------+
operand A --------->| arithmetic     |
operand B --------->|                |
                    +----------------+

                    +----------------+
operand A --------->| logic unit     |
operand B --------->|                |
                    +----------------+

                    +----------------+
operand A --------->| shifter        |
operand B --------->|                |
                    +----------------+

                    +----------------+
operand A --------->| comparator     |
operand B --------->|                |
                    +----------------+

                         |
                         v
                   operation selects
                         |
                         v
                       result
```

All of those blocks can exist concurrently.

### Understanding gap: "Does the ALU call the arithmetic unit?"

Not in the software sense.

The arithmetic, logic, shift, and comparison hardware can all evaluate.
Control logic selects the appropriate result.

------------------------------------------------------------------------

## 13. Flags

LACOODA used five important flags:

``` text
Z  zero
N  negative
C  carry
V  signed overflow
DZ divide-by-zero
```

These teach a critical distinction:

``` text
ALU result = combinational output
architectural status register = stored state
```

The ALU can calculate candidate flags continuously. The status register
captures them only when control says the instruction should update
architectural status.

------------------------------------------------------------------------

## 14. Simulation Warning vs Failure

Icarus produced warnings such as:

``` text
constant selects in always_* processes are not currently supported
(all bits will be included)
```

The important lesson was not to classify every warning as a broken CPU.

A simulator warning may describe a simulator limitation or conservative
sensitivity handling.

Verification discipline means asking:

1.  Did elaboration succeed?
2.  Did simulation run?
3.  Did checks pass?
4.  Is the warning about semantics, synthesis, portability, or merely
    tool behavior?

------------------------------------------------------------------------

# Part IV --- Stage 2: The Register File

## 15. Registers Create Architectural State

The register file introduced persistent CPU state.

Default architecture:

``` text
64 registers
64 bits per register
R0 hardwired to zero
```

Two asynchronous read ports and one synchronous write port were used.

Conceptually:

``` text
             rs1 ----> [ register file ] ----> value A
             rs2 ----> [               ] ----> value B

             rd  ----> [               ]
             data ----> [               ]
             we  ----> [               ]
             clk -----> [               ]
```

------------------------------------------------------------------------

## 16. Why Reads Can Be Immediate but Writes Wait

A combinational read can be modeled as:

``` systemverilog
assign read_data = registers[read_address];
```

A write changes state:

``` systemverilog
always_ff @(posedge clk) begin
    if (write_enable)
        registers[write_address] <= write_data;
end
```

### Understanding gap

> Why can the CPU "see" a register immediately but only change it on the
> clock?

Because those are two different hardware paths.

Read logic observes stored bits. Write logic changes the storage
elements.

------------------------------------------------------------------------

## 17. R0

R0 was defined to read as zero and ignore writes.

This is an example of an **architectural rule**, not merely a coding
trick.

The register file must enforce the rule even if an instruction tries to
write R0.

Stage 2 regression reached **8/8 tests passing**.

------------------------------------------------------------------------

# Part V --- Stage 3: Build the Datapath

## 18. Connect Registers to the ALU

The datapath connects:

``` text
register file
     |
     +---- operand A --------\
     |                        \
     +---- register B ----+    ALU ---> result ---> writeback
                          |
immediate ----------------+--> B mux
```

A key line was:

``` systemverilog
assign operand_b =
    use_immediate ? immediate : register_b;
```

This is a hardware multiplexer.

``` text
                 +------+
register B ----->|      |
                 | MUX  |----> operand B
immediate ------>|      |
                 +--+---+
                    ^
             use_immediate
```

------------------------------------------------------------------------

## 19. Write Authorization

The datapath should not write a register merely because an ALU produced
a value.

The design progressively introduced conditions such as:

``` systemverilog
register_write_enable
valid
reset state
instruction validity
```

This led to an important CPU design principle:

> Calculating a value and committing architectural state are separate
> events.

Stage 3 regression reached **21/21 tests passing**.

------------------------------------------------------------------------

# Part VI --- Stage 4: Instruction Encoding and Decoding

## 20. The 64-bit Instruction Word

The CPU developed in this journey used this instruction layout:

``` text
63                                                   0
+--------+---+---+--------+--------+--------+--------+----------------+
|reserved| S | I | opcode |   rd   |  rs1   |  rs2   |     imm32      |
+--------+---+---+--------+--------+--------+--------+----------------+
  6 bits   1   1   6 bits   6 bits   6 bits   6 bits      32 bits

63:58 reserved
57    S / update status
56    I / immediate mode
55:50 opcode
49:44 rd
43:38 rs1
37:32 rs2
31:0  immediate
```

This was the bridge from "ALU hardware" to "processor ISA."

------------------------------------------------------------------------

## 21. Packed Struct Overlay

The instruction fields were represented with a packed struct
conceptually like:

``` systemverilog
typedef struct packed {
    logic [RESERVED_WIDTH-1:0] reserved;
    logic update_status;
    logic immediate_mode;
    opcode_t opcode;
    reg_addr_t rd;
    reg_addr_t rs1;
    reg_addr_t rs2;
    imm_t imm32;
} instruction_fields_t;
```

Then the decoder could do:

``` systemverilog
instruction_fields_t fields;

assign fields = instruction;
```

### Understanding gap: "How can one assignment decode everything?"

It does not perform semantic decoding.

Both sides are packed collections of bits.

The struct declaration defines how the bit positions map onto names.

Conceptually:

``` text
instruction[63:58] ---> fields.reserved
instruction[57]    ---> fields.update_status
instruction[56]    ---> fields.immediate_mode
instruction[55:50] ---> fields.opcode
...
```

The assignment is a bit-level wiring interpretation.

The decoder still has to determine whether those fields form a legal
instruction and what control signals they imply.

------------------------------------------------------------------------

## 22. Legal Encoding Is More Than a Valid Opcode

The decoder enforced format rules.

Examples from the architecture:

### MOV / PASS_A

Expected form:

``` text
register mode
RS1 contains source
RS2 = 0
IMM = 0
S = 0
```

### MOVI / PASS_B

Expected form:

``` text
immediate mode
RS1 = 0
RS2 = 0
S = 0
```

### Unary operations

For operations such as:

``` text
NEG
ABS
NOT
```

the unused second source must not contain arbitrary garbage.

### Binary register form

``` text
I = 0
IMM = 0
```

### Binary immediate form

``` text
I = 1
RS2 = 0
```

This prevents multiple bit patterns from ambiguously representing the
same semantic instruction.

------------------------------------------------------------------------

## 23. Decoder and Datapath: Which Comes First?

This was one of the central understanding gaps.

The source might contain:

``` systemverilog
decoder u_decoder (...);
datapath u_datapath (...);
```

But modules are not called one after another.

The actual dependency is:

``` text
instruction bits
      |
      v
   decoder
      |
      | control wires
      v
   datapath
      |
      v
    result
```

The decoder's combinational outputs respond to instruction bits. The
datapath's combinational logic responds to those outputs.

Physically and in RTL simulation, they form a connected combinational
network.

At the clock edge, state updates are committed.

------------------------------------------------------------------------

## 24. `cpu_core.sv`

The CPU core became the integration point for:

``` text
decoder
datapath
branch logic later
memory-operation control later
```

Important gating concepts included:

``` systemverilog
assign effective_register_write =
    instruction_enable &&
    instruction_valid &&
    register_write_enable;

assign effective_flags_write =
    instruction_enable &&
    instruction_valid &&
    flags_write_enable;
```

and an execution validity concept.

The decoder says what an instruction *requests*. The integration layer
decides whether the request is currently authorized to affect state.

Stage 4 CPU-core regression reached **16 checks passing**.

------------------------------------------------------------------------

# Part VII --- Stage 5: Fetch and Program Execution

## 25. A CPU Core Is Not Yet a Program-Running CPU

Before Stage 5, the core could execute an instruction supplied to it.

But something still had to answer:

> Which instruction comes next?

That requires a program counter and instruction storage.

------------------------------------------------------------------------

## 26. Program Counter

The program counter stores the address of the current/next instruction.

The initial design was byte addressed.

Because the instruction width was 64 bits:

``` text
64 bits / 8 = 8 bytes per instruction
```

Sequential PCs therefore looked like:

``` text
0
8
16
24
32
...
```

The PC logic already anticipated redirection:

``` text
if reset:
    PC = 0
else if redirect:
    PC = target
else if enabled:
    PC = PC + INSTRUCTION_BYTES
```

------------------------------------------------------------------------

## 27. Instruction Memory

The initial instruction memory was a simple simulation/synthesizable ROM
abstraction.

It was **not DDR3**.

This distinction became important later when discussing the Tang Primer
20K.

The ROM could be initialized using:

``` systemverilog
initial begin
    for (int i = 0; i < DEPTH; i++)
        memory[i] = '0;

    $readmemh(INIT_FILE, memory);
end
```

Zeroing the memory before `$readmemh` avoids unknown values in unused
entries.

------------------------------------------------------------------------

## 28. `program_0.hex`

A small program became the first real sequence of machine instructions.

An early example was effectively:

``` text
MOVI R1, 50
MOVI R2, 75
ADD  R3, R1, R2
```

Expected final value:

``` text
R3 = 125
```

This is where the project changed psychologically from "modules under
test" to "a processor running a program."

------------------------------------------------------------------------

## 29. What if the Program Is Larger Than Memory?

A memory depth is a hardware/storage limit.

If a program contains more initialized words than the modeled memory,
the correct solution is not to assume the tool will somehow expand the
hardware.

This led into parameterization, memory sizing, and eventually external
memory.

------------------------------------------------------------------------

# Part VIII --- Stage 6: Control Flow

## 30. Sequential Execution Is Not Enough

Without control flow:

``` text
PC = PC + 8
PC = PC + 8
PC = PC + 8
...
```

Every program is just a straight line.

A useful CPU needs branches and jumps.

Stage 6 introduced control-flow opcodes in the unused opcode space:

``` text
0x28 CTRL_JMP
0x29 CTRL_BEQ
0x2A CTRL_BNE
0x2B CTRL_BLT
0x2C CTRL_BGE
0x2D CTRL_BLTU
0x2E CTRL_BGEU
```

Signed and unsigned comparisons were deliberately distinguished.

------------------------------------------------------------------------

## 31. Branch Unit

The branch unit accepts:

``` text
enable
condition
lhs
rhs
target
```

and produces:

``` text
redirect
redirect_target
```

Conceptually:

``` text
R1 ----\
        compare ---- condition true? ---- redirect
R2 ----/                                  |
                                           +---- target
```

The branch does not need to write a general-purpose register.

------------------------------------------------------------------------

## 32. Branch Program

A Stage 6 test program used the idea:

``` text
0x00 MOVI R1,5
0x08 MOVI R2,5
0x10 BEQ R1,R2,0x20
0x18 MOVI R3,111   ; must be skipped
0x20 MOVI R3,222
```

Expected PC flow:

``` text
0 -> 8 -> 16 -> 32
```

Expected result:

``` text
R3 = 222
```

------------------------------------------------------------------------

## 33. Retirement

This stage exposed another important word: **retire**.

An instruction can be:

``` text
fetched
decoded
evaluated
waiting
completed
retired
```

Retirement means the instruction is finished as an architectural
operation and the machine may move beyond it.

This distinction becomes essential when memory can stall.

------------------------------------------------------------------------

# Part IX --- Stage 7: LOAD, STORE, and Data Memory

## 34. Why Registers Are Not Enough

The CPU had 64 registers, but a game, stack, arrays, card state, AI
data, and assets cannot live entirely in 64 registers.

The CPU needed addressable data memory.

The basic operations were:

``` text
LOAD  Rd, [RsBase + offset]
STORE RsData, [RsBase + offset]
```

------------------------------------------------------------------------

## 35. Effective Address

The existing ALU could calculate:

``` text
effective address = base register + immediate offset
```

This is a good example of reusing the datapath instead of creating
special arithmetic hardware for memory.

### LOAD flow

``` text
base register
     |
     +-- + offset --> address --> memory
                                  |
                                  v
                              read data
                                  |
                                  v
                              writeback
                                  |
                                  v
                                  Rd
```

### STORE flow

``` text
base register -- + offset --> address
source register -------------> write data
                                |
                                v
                              memory
```

STORE does not write a CPU register.

------------------------------------------------------------------------

## 36. Byte Addressing

The architecture uses byte addresses.

For a 64-bit data word:

``` text
DATA_WIDTH = 64
DATA_BYTES = 8
```

Word addresses therefore appear at:

``` text
0
8
16
24
...
```

This is why `DATA_BYTES` is an architectural derived parameter and not
something that should be hardcoded as `8` everywhere.

------------------------------------------------------------------------

# Part X --- Parameterization

## 37. The Question That Changed the Architecture

A critical question was:

> If I change one `localparam` in `cpu_pkg`, is the entire codebase
> guaranteed to adapt?

The answer at the time was **no**.

A design can look parameterized while still containing hidden
assumptions:

``` text
[63:0]
[5:0]
64'h...
6'h...
+8
<<3
bit 63
fixed instruction slices
```

Parameterization requires an audit, not just a few `parameter`
declarations.

------------------------------------------------------------------------

## 38. Root Parameters

The proposed root architectural parameters became:

``` text
DATA_WIDTH
REG_COUNT
INSTRUCTION_WIDTH
IMMEDIATE_WIDTH
OPCODE_WIDTH
INSTRUCTION_MEMORY_DEPTH
```

plus configuration such as the initialization filename.

Everything possible should be derived from these.

Examples:

``` systemverilog
DATA_BYTES = DATA_WIDTH / 8;

REG_ADDR_WIDTH = $clog2(REG_COUNT);

INSTRUCTION_BYTES = INSTRUCTION_WIDTH / 8;
```

------------------------------------------------------------------------

## 39. Derive Instruction Layout

Instead of manually declaring every bit position, calculate how many
bits are required.

Conceptually:

``` systemverilog
USED_INSTRUCTION_BITS =
    IMMEDIATE_WIDTH +
    (3 * REG_ADDR_WIDTH) +
    OPCODE_WIDTH +
    2;
```

The final `2` represents the I and S bits.

Then:

``` systemverilog
RESERVED_WIDTH =
    INSTRUCTION_WIDTH - USED_INSTRUCTION_BITS;
```

Default configuration:

``` text
immediate             32
3 register fields     18
opcode                  6
I/S                     2
-------------------------
used                   58

instruction            64
reserved                6
```

------------------------------------------------------------------------

## 40. Parameter Constraints

Parameterization does not mean every integer is legal.

Examples of meaningful constraints:

``` text
DATA_WIDTH >= 64
DATA_WIDTH % 8 == 0
INSTRUCTION_WIDTH % 8 == 0
DATA_WIDTH >= IMMEDIATE_WIDTH
USED_INSTRUCTION_BITS <= INSTRUCTION_WIDTH
```

The design philosophy became:

> Every legal root configuration should propagate automatically. Every
> illegal configuration should fail clearly rather than silently produce
> broken hardware.

------------------------------------------------------------------------

## 41. The 777 → 9 Bug

A parameterized test later exposed a subtle mistake.

The test encoded:

``` systemverilog
imm_t'(777)
```

and expected:

``` text
777
```

That is correct with a 32-bit immediate.

But with:

``` text
IMMEDIATE_WIDTH = 8
```

the field contains only eight bits.

``` text
777 = 0x309

8-bit encoding:
0x09

decimal:
9
```

The CPU was correct. The testbench was wrong.

The correct test expectation must derive from the encoded value:

``` systemverilog
localparam imm_t STORE_TEST_IMM = imm_t'(777);

localparam data_t STORE_TEST_VALUE =
    sign_extend_imm32(STORE_TEST_IMM);
```

This is a major hardware lesson:

> Tests must obey finite-width hardware semantics too.

------------------------------------------------------------------------

## 42. The Memory-Map Overflow Bug

Another parameter probe found:

``` systemverilog
localparam int DATA_MEMORY_SIZE_BYTES =
    DATA_MEMORY_DEPTH * DATA_BYTES;
```

This used a SystemVerilog `int`, which is a 32-bit signed type.

A large valid memory size could overflow the intermediate calculation.

For example:

``` text
536,870,912 words * 8 bytes
= 4,294,967,296 bytes
= 0x1_0000_0000
```

That does not fit in 32 unsigned bits, much less a positive 32-bit
signed `int`.

The fix was to perform the calculation at architectural address width:

``` systemverilog
localparam data_t DATA_MEMORY_SIZE_BYTES =
    data_t'(DATA_MEMORY_DEPTH) * data_t'(DATA_BYTES);

localparam data_t DATA_MEMORY_LIMIT =
    DATA_MEMORY_BASE + DATA_MEMORY_SIZE_BYTES;
```

### Understanding gap

Parameters and constants are still typed bit patterns.

"Compile-time" does not mean "infinite precision."

------------------------------------------------------------------------

# Part XI --- Why a Bus?

## 43. Internal CPU Communication First

Before introducing a bus, the CPU already had many connections:

``` text
decoder -> datapath
register file -> ALU
ALU -> writeback
branch unit -> redirect
```

Why not put `valid/ready` on every one?

Because the current internal CPU is designed around a **fixed
synchronous timing contract**.

Register reads are combinational. The ALU is combinational. Writes
happen at the clock edge.

If all combinational paths meet the target clock period, the CPU can
safely capture the result.

------------------------------------------------------------------------

## 44. What Actually Guarantees Internal Timing?

RTL simulation proves logical behavior under the RTL timing model.

It does **not** prove that the FPGA can physically evaluate a long
combinational path before the next clock edge.

The real physical guarantee comes from:

``` text
synthesis
    |
placement
    |
routing
    |
static timing analysis
```

If the path is too slow:

``` text
lower clock frequency
or
pipeline the operation
or
make it multicycle
or
use a handshake/done signal
```

### Important caveat

"Internal" does not automatically mean "no handshake."

If a future internal divider, cache, FPU, or accelerator has variable
latency, it needs a fixed multicycle contract or a ready/done/stall
mechanism.

------------------------------------------------------------------------

## 45. External Memory Is Different

DDR3, MMIO devices, peripherals, and shared resources may not answer in
one CPU cycle.

So the CPU needs a protocol.

The simple LACOODA data bus uses:

``` text
CPU -> outside:
valid
write
address
write_data

outside -> CPU:
ready
read_data
```

A transaction completes when:

``` text
valid && ready
```

------------------------------------------------------------------------

## 46. Hold-Until-Ready Rule

If the CPU asserts:

``` text
valid = 1
```

but receives:

``` text
ready = 0
```

it must not casually change the request.

It holds:

``` text
valid
write
address
write_data
```

until the receiver accepts the transaction.

This is the practical guarantee that lets a future DDR controller take
many cycles without changing LOAD/STORE semantics.

------------------------------------------------------------------------

# Part XII --- Wrapping the CPU

## 47. Why the Bus Became Its Own Folder

At first, the "bus" was only point-to-point signals:

``` text
CPU <------> RAM
```

There was no actual bus module.

Once the design needed:

``` text
address decoding
routing
multiple future slaves
eventual arbitration
```

the interconnect became an architectural subsystem.

The practical structure became:

``` text
rtl/
├── packages/
├── cpu/
├── bus/
├── memory/
└── soc/
```

------------------------------------------------------------------------

## 48. Final Practical Folder Structure

The final CPU project was reorganized approximately as:

``` text
verilog-staging/
├── rtl/
│   ├── packages/
│   │   ├── alu_pkg.sv
│   │   ├── cpu_pkg.sv
│   │   └── bus_pkg.sv
│   │
│   ├── cpu/
│   │   ├── cpu.sv
│   │   ├── alu/
│   │   │   ├── alu.sv
│   │   │   ├── arithmetic.sv
│   │   │   ├── comparator.sv
│   │   │   ├── logic_unit.sv
│   │   │   └── shifter.sv
│   │   ├── core/
│   │   │   ├── cpu_core.sv
│   │   │   ├── decoder.sv
│   │   │   ├── datapath.sv
│   │   │   ├── register_file.sv
│   │   │   ├── status_register.sv
│   │   │   └── branch_unit.sv
│   │   └── fetch/
│   │       ├── instruction_fetch.sv
│   │       └── program_counter.sv
│   │
│   ├── bus/
│   │   ├── address_decoder.sv
│   │   └── bus_interconnect.sv
│   │
│   ├── memory/
│   │   ├── instruction_memory.sv
│   │   └── data_memory.sv
│   │
│   └── soc/
│       └── cpu_system.sv
│
├── sim/
│   └── testbench/
│       ├── cpu/
│       ├── bus/
│       ├── memory/
│       └── soc/
│
├── programs/
│   └── program_0.hex
│
└── run.sh
```

This is more than file organization. It reflects architectural
ownership.

------------------------------------------------------------------------

## 49. Final CPU Boundary: Separate I-BUS and D-BUS

An important late-stage decision was to keep separate instruction and
data interfaces at the CPU boundary.

``` text
               +----------------+
               |      CPU       |
               +------+---------+
                      |
              +-------+-------+
              |               |
            I-BUS           D-BUS
              |               |
          instruction       LOAD/STORE
            fetch
```

This is a Harvard-style external boundary.

It does **not** require physically separate DDR chips later.

The SoC can arbitrate both masters into shared DDR if desired.

------------------------------------------------------------------------

## 50. Instruction Memory Moved Outside the CPU

Earlier:

``` text
CPU-ish system
   |
   +-- instruction memory
```

Final boundary:

``` text
CPU
 |
 +-- I-BUS ----> external instruction memory / future memory system
```

This matters because the CPU should describe the processor, not one
specific storage implementation.

------------------------------------------------------------------------

## 51. Instruction Fetch Buffer

Once instruction fetch uses `valid/ready`, the CPU needs to distinguish:

``` text
request started
request waiting
instruction accepted
instruction buffered
instruction executing
instruction retired
```

A one-entry instruction buffer is enough for the simple non-pipelined
design.

The key guarantees are:

1.  A started fetch remains active until accepted.
2.  The fetch address remains stable while waiting.
3.  Fetch acceptance alone does not advance the PC.
4.  Retirement advances or redirects the PC.
5.  Pausing `run` must not abandon an already-started transaction.

------------------------------------------------------------------------

## 52. Pause During a Transaction

This is a subtle correctness case.

Suppose:

``` text
STORE begins
valid = 1
ready = 0
```

Then the user/system deasserts:

``` text
run = 0
```

The CPU must not throw the STORE away.

Correct behavior:

``` text
valid stays high
request stays stable
wait for ready
complete exactly once
retire instruction
then remain paused
```

The same atomicity principle was applied to instruction fetch.

------------------------------------------------------------------------

# Part XIII --- Bus Interconnect and Address Decoding

## 53. Address Decoder

The CPU should emit an address without knowing which physical device
owns it.

The address decoder answers:

``` text
Does this address belong to local RAM?
GPU?
timer?
controller?
DDR?
something else?
```

At the current stage, only local data memory is mapped.

Future regions can be added without redesigning the CPU ISA.

------------------------------------------------------------------------

## 54. Interconnect

The interconnect receives the CPU master request:

``` text
master_valid
master_write
master_address
master_write_data
```

and routes it to the selected slave.

It returns:

``` text
master_ready
master_read_data
```

Conceptually:

``` text
                    CPU D-BUS
                        |
                        v
                +---------------+
                | interconnect  |
                +-------+-------+
                        |
               address decoder
                        |
          +-------------+-------------+
          |             |             |
         RAM          GPU/MMIO       DDR
       current          future       future
```

------------------------------------------------------------------------

## 55. Unmapped Addresses

A system must define what happens if no slave owns an address.

The current simple design preserves a no-fault behavior:

``` text
unmapped read/write:
ready = 1
read_data = 0
```

That is a policy, not a universal truth.

A future architecture could instead introduce:

``` text
bus fault
exception
trap
error response
```

------------------------------------------------------------------------

# Part XIV --- Verification as Part of the Architecture

## 56. Unit Tests Are Not Enough

The development journey progressively accumulated tests:

``` text
ALU
register file
datapath
decoder
CPU core
program counter
branch unit
instruction fetch
data memory
bus interconnect
CPU boundary
CPU system
```

A passing ALU does not prove a CPU.

A passing CPU core does not prove fetch.

A passing fetch unit does not prove bus routing.

A passing default configuration does not prove parameterization.

Verification must match architectural layers.

------------------------------------------------------------------------

## 57. Testbench Tasks

Testbenches used tasks to avoid repeating stimulus/check logic.

A task is testbench procedural organization. It is not the same thing as
instantiating hardware.

This distinction is useful:

``` text
module instance -> hardware structure
task call       -> procedural simulation behavior
```

------------------------------------------------------------------------

## 58. Waveforms

VCD files and GTKWave are essential because hardware bugs are often
temporal.

Instead of only asking:

``` text
What value is R3?
```

a waveform lets you ask:

``` text
When did valid rise?
How long did ready stay low?
Did address remain stable?
Did PC change before retirement?
Did write_enable pulse on the correct edge?
```

This is often the difference between guessing and debugging.

------------------------------------------------------------------------

## 59. Icarus and Tool-Specific Problems

During development, Icarus exposed a packed-struct indexing issue in a
testbench expression similar to:

``` systemverilog
fields.reserved[bit_index] = 1'b1;
```

A more portable construction used a shifted value:

``` systemverilog
fields.reserved =
    RESERVED_WIDTH'(1) << bit_index;
```

The lesson is not "never index a packed struct."

The lesson is:

> Your chosen simulator is part of the practical development
> environment. Legal-looking or even standard-conforming SystemVerilog
> can encounter incomplete tool support.

------------------------------------------------------------------------

## 60. Duplicate Module Definitions

After reorganizing testbenches into subdirectories, stale copies can
cause recursive compilation to see two modules with the same name.

Bad repository state:

``` text
sim/testbench/cpu_tb.sv
sim/testbench/cpu/cpu_tb.sv
```

Both declaring:

``` systemverilog
module cpu_tb;
```

The fix is not to rename stale copies arbitrarily.

Delete the obsolete copies and maintain one canonical location.

This is a build-system lesson:

> Source-tree organization affects elaboration just as surely as RTL
> logic does.

------------------------------------------------------------------------

## 61. `run.sh`

The regression runner standardized:

``` text
compile
run
collect VCD
repeat
optionally launch GTKWave
```

Typical commands:

``` bash
iverilog -g2012 -Wall ...
vvp ...
```

and:

``` bash
./run.sh --no-gui
```

for regression.

A reproducible one-command test suite is part of the processor, not
optional housekeeping.

------------------------------------------------------------------------

# Part XV --- Default Success vs Architectural Success

## 62. "All Default Tests Pass" Is Not the End

At one point, all 12 default tests passed.

That was excellent, but two parameterized findings remained:

1.  large memory-map overflow,
2.  immediate-width test expectation.

This distinction is critical.

``` text
default configuration works
        !=
architecture is safely parameterized
```

The final acceptance mindset became:

``` text
default regression                 PASS
large-memory-map probe             PASS
IMMEDIATE_WIDTH=8 probe            PASS
duplicate RTL definitions          0
duplicate testbench definitions    0
recursive elaboration              PASS
```

------------------------------------------------------------------------

# Part XVI --- The FPGA Is Not the Simulator

## 63. Simulation vs Synthesis

RTL simulation answers:

> Does the described logic behave correctly according to the model and
> testbench?

Synthesis answers:

> What FPGA hardware implements this description?

Place and route answer:

> Where does that hardware physically go, and how is it connected?

Static timing analysis answers:

> Can signals actually propagate fast enough for the requested clock?

A CPU can pass every functional test and still fail timing at an
aggressive frequency.

------------------------------------------------------------------------

## 64. Current Combinational Complexity

The current ALU includes operations such as multiply and divide.

A combinational divider can become expensive or slow on FPGA.

That does not automatically mean the design is wrong.

It means the next question after functional correctness is physical
implementation:

``` text
resource use?
critical path?
maximum clock?
DSP inference?
multicycle alternative?
pipeline?
```

Do not confuse a functional simulator's instant-looking arithmetic with
physical zero-time hardware.

------------------------------------------------------------------------

# Part XVII --- Tang Primer 20K System Context

## 65. The Board Context

The target direction discussed was the Sipeed Tang Primer 20K using a
Gowin GW2A-LV18 FPGA.

The important architectural lesson was not memorizing a marketing table.
It was learning the categories of resources:

``` text
LUTs       -> combinational logic
flip-flops -> state/registers
BRAM       -> fast on-chip memory
DSP/mults  -> arithmetic resources
PLL        -> clock generation
DDR3       -> large external working memory
flash/SD   -> persistent storage
I/O        -> display/controllers/etc.
```

------------------------------------------------------------------------

## 66. The 128 MiB DDR3 Is Shared System Memory

A major clarification in the journey was:

> The board's external DDR3 is not "instruction memory."

It is potential shared system RAM.

Future uses include:

``` text
program code
game state
heap/stack
framebuffers
sprites/assets
AI model data
AI activations
GPU command/data structures
```

The CPU's simple `instruction_memory.sv` is not a DDR3 controller.

DDR3 requires a controller and has variable latency, which is exactly
why freezing a handshake-based CPU boundary first was useful.

------------------------------------------------------------------------

## 67. SD Card Is Storage, Not Working RAM

The SD card can persist:

``` text
programs
game assets
AI model
save files
```

A sensible future boot/data path is:

``` text
microSD
   |
   v
load data
   |
   v
DDR3
   |
   +---- CPU
   +---- GPU
   +---- AI accelerator
```

The SD card is not a replacement for low-latency working memory.

------------------------------------------------------------------------

# Part XVIII --- GPU Direction

## 68. Keep the GPU Separate

The chosen direction was a custom SystemVerilog GPU rather than
implementing graphics through Vulkan.

The first practical target is not a desktop-class 3D GPU.

It is a 2D accelerator suitable for:

``` text
OpenJoey2 UI
sprites
tiles
pixel art
framebuffer operations
eventual top-down dungeon crawler
```

Architecturally:

``` text
                  shared memory
                      |
          +-----------+-----------+
          |                       |
         CPU                     GPU
          |                       |
          +---- commands/MMIO ----+
```

The GPU should have its own command processing/rendering logic rather
than bloating the CPU ISA with game-specific drawing instructions.

------------------------------------------------------------------------

## 69. Why a Second Game Was Useful

A top-down pixel-art dungeon crawler was selected as another target.

That was not merely a game-design choice.

It is an architecture test.

If both:

``` text
OpenJoey2
and
a dungeon crawler
```

can run without changing the CPU's fundamental stages, then the hardware
is becoming a general-purpose game system rather than a hardcoded
Yu-Gi-Oh machine.

Game mechanics belong in software.

Generic acceleration belongs in hardware.

------------------------------------------------------------------------

# Part XIX --- AI Accelerator Direction

## 70. AI Does Not Belong Inside the ALU

The project also discussed a small AI model, roughly in the few-megabyte
range, for inference.

A sensible future architecture is:

``` text
training:
laptop / workstation

deployment:
microSD -> DDR3 -> FPGA AI accelerator
```

The accelerator can be a separate subsystem with INT8 MAC-oriented
hardware later.

This preserves modularity:

``` text
CPU = general program execution
GPU = graphics
AI accelerator = inference
DDR = shared working memory
bus/interconnect = communication
```

------------------------------------------------------------------------

# Part XX --- Complete CPU Mental Model

## 71. One Ordinary ALU Instruction

Consider:

``` text
ADD R3, R1, R2
```

At a high level:

``` text
1. PC identifies instruction address.
2. I-BUS fetch request is made.
3. Instruction source asserts ready.
4. Instruction is buffered.
5. Packed fields expose opcode/RD/RS1/RS2.
6. Decoder validates encoding.
7. Register file exposes R1 and R2 values.
8. ALU computes addition.
9. Control authorizes R3 write.
10. At the clock edge, R3 captures the result.
11. Instruction retires.
12. PC advances.
13. Next fetch begins.
```

Many of steps 5--9 are combinational and coexist in one cycle.

Do not imagine twelve software function calls.

------------------------------------------------------------------------

## 72. One LOAD with a Slow Device

``` text
LOAD R3, [R2 + 8]
```

Flow:

``` text
fetch instruction
    |
decode
    |
read R2
    |
calculate address R2+8
    |
assert D-BUS valid/read/address
    |
ready=0
    |
HOLD
HOLD
HOLD
    |
ready=1 + read_data
    |
write R3 at retirement edge
    |
advance PC
```

This is exactly why `valid/ready` exists.

------------------------------------------------------------------------

## 73. One Taken Branch

``` text
BEQ R1, R3, target
```

Flow:

``` text
fetch
  |
decode
  |
read R1/R3
  |
branch compare
  |
equal?
  |
 yes
  |
redirect = 1
target = branch target
  |
retirement edge
  |
PC <- target
  |
fetch target instruction
```

------------------------------------------------------------------------

# Part XXI --- Understanding Gaps: The Questions Worth Remembering

## 74. "Which Module Runs First?"

Wrong mental model:

``` text
decoder runs
then datapath runs
then ALU runs
```

Better:

``` text
instruction
    |
    v
decoder --control--> datapath --operands--> ALU
```

The hardware coexists. Dependencies cause propagation.

------------------------------------------------------------------------

## 75. "Why Doesn't This Need Another `assign`?"

If:

``` systemverilog
logic x;

producer p(.out(x));
consumer c(.in(x));
```

then `x` is already the connection.

------------------------------------------------------------------------

## 76. "Why Does `assign fields = instruction` Work?"

Because both are packed bit representations.

It maps bits.

Semantic validation comes afterward.

------------------------------------------------------------------------

## 77. "Why Does a Clock Matter?"

Combinational logic calculates.

Sequential logic remembers.

The clock defines when architectural state is allowed to capture its
next value.

------------------------------------------------------------------------

## 78. "Are Fetch, Decode, Execute, and Retire Four Clock Cycles?"

Not necessarily.

They are conceptual responsibilities.

A pipelined processor may make them explicit pipeline stages. The simple
LACOODA design does not automatically become a four-stage pipeline
because we use those four words.

------------------------------------------------------------------------

## 79. "Why Doesn't Internal CPU Logic Need `valid/ready`?"

Because the current internal paths have a fixed synchronous timing
contract.

If physical timing closes, the result is ready before the capture edge.

External devices can have variable latency.

If an internal unit becomes variable latency, it too needs a completion
protocol or defined multicycle control.

------------------------------------------------------------------------

## 80. "What Guarantees the ALU Finishes Before the Clock?"

Not hope.

Not source order.

Not the simulator.

**Static timing analysis** against the target FPGA and requested clock.

------------------------------------------------------------------------

## 81. "Why Did 777 Become 9?"

Finite width.

``` text
777 = binary value wider than 8 bits
8-bit immediate keeps only 8 bits
result = 9
```

Hardware integers are bit vectors with widths.

------------------------------------------------------------------------

## 82. "Why Did a Huge Memory Become Zero?"

Finite-width intermediate arithmetic.

A 32-bit `int` overflowed before the result reached the 64-bit
architectural type.

Cast operands before arithmetic when the intermediate itself needs the
wider width.

------------------------------------------------------------------------

## 83. "Why Is the Bus in Its Own Folder?"

Wires alone do not require a folder.

Routing/decoding/arbitration is a subsystem.

Once the project has an actual interconnect, `rtl/bus/` reflects real
architectural ownership.

------------------------------------------------------------------------

## 84. "What Is the CPU?"

The final answer became:

``` text
CPU owns:
    PC
    instruction fetch control/buffer
    decoder
    registers
    ALU/datapath
    status
    branch logic
    LOAD/STORE transaction generation

CPU does not own:
    physical instruction memory
    physical data memory
    DDR3
    GPU
    controller
    timers
    HDMI
    audio
```

That boundary is one of the most important outcomes of the entire
journey.

------------------------------------------------------------------------

# Part XXII --- Development Stages Recap

## 85. Stage 1 --- ALU

Built:

``` text
arithmetic
logic
shift/rotate
comparison
flags
ALU integration
```

Learned:

``` text
combinational logic
submodule composition
flags
testbench fundamentals
```

Result:

``` text
134/134 ALU checks passed in the development regression.
```

------------------------------------------------------------------------

## 86. Stage 2 --- Register File

Built:

``` text
64 × 64-bit registers
two reads
one write
R0 = zero
```

Learned:

``` text
state
async read
sync write
clock edge
```

Result:

``` text
8/8 regression checks passed.
```

------------------------------------------------------------------------

## 87. Stage 3 --- Datapath

Built:

``` text
register file -> operand selection -> ALU -> writeback
status register
```

Learned:

``` text
muxes
control
write gating
state commitment
```

Result:

``` text
21/21 regression checks passed.
```

------------------------------------------------------------------------

## 88. Stage 4 --- ISA/Decoder/CPU Core

Built:

``` text
64-bit instruction format
packed fields
decoder
validation
CPU core integration
```

Learned:

``` text
machine encoding
packed structs
ports vs signals
concurrent modules
decode-to-datapath propagation
```

Result:

``` text
CPU core test passed 16 checks in the recorded development run.
```

------------------------------------------------------------------------

## 89. Stage 5 --- Fetch

Built:

``` text
PC
instruction memory
hex program loading
instruction fetch
CPU system
```

Learned:

``` text
program sequencing
byte addresses
ROM initialization
program execution
```

------------------------------------------------------------------------

## 90. Stage 6 --- Branches

Built:

``` text
JMP
BEQ/BNE
signed branches
unsigned branches
branch unit
PC redirect
```

Learned:

``` text
control flow
comparison semantics
retirement/redirect relationship
```

------------------------------------------------------------------------

## 91. Stage 7 --- Data Memory

Built:

``` text
LOAD
STORE
effective addresses
data memory
memory writeback
```

Learned:

``` text
addressable data
memory vs registers
load/store semantics
```

------------------------------------------------------------------------

## 92. Bus/Wrap Substage

Built:

``` text
valid/ready transaction contract
CPU wrapper
instruction bus
data bus
instruction buffer
address decoder
bus interconnect
minimal SoC wrapper
```

Learned:

``` text
fixed vs variable latency
CPU/system boundary
stalling
atomic completion
routing
```

------------------------------------------------------------------------

## 93. Parameterization Hardening

Found and fixed:

``` text
immediate-width test assumption
memory-map intermediate overflow
duplicate testbench definitions
```

Learned:

``` text
parameterization must be tested
compile-time arithmetic has widths
tests can contain architecture bugs
repository structure affects builds
```

------------------------------------------------------------------------

# Part XXIII --- Hands-On Exercises

## 94. Exercise: Follow a Signal

Choose:

``` text
decoded opcode
```

Trace it from:

``` text
instruction bits
-> packed fields
-> decoder
-> parent signal
-> datapath
-> ALU
```

Do not describe "function calls." Draw wires.

------------------------------------------------------------------------

## 95. Exercise: Break the Immediate Width

Set:

``` text
IMMEDIATE_WIDTH = 8
```

Predict the encoded values of:

``` text
5
127
128
255
256
777
-1
```

Then compare against simulation.

------------------------------------------------------------------------

## 96. Exercise: Stall I-BUS

Hold:

``` text
ibus_ready = 0
```

for several cycles.

Verify in GTKWave:

``` text
ibus_valid remains asserted
ibus_address remains stable
PC does not incorrectly advance
```

Then assert ready.

------------------------------------------------------------------------

## 97. Exercise: Stall D-BUS

Execute a STORE.

Hold:

``` text
dbus_ready = 0
```

Verify:

``` text
valid stable
write stable
address stable
write_data stable
PC stable
```

Then complete the handshake.

------------------------------------------------------------------------

## 98. Exercise: Pause Mid-Transaction

While a STORE is waiting:

``` text
run = 0
```

The transaction must still finish exactly once.

Then the CPU should remain paused before starting another instruction.

------------------------------------------------------------------------

## 99. Exercise: Branch Around an Instruction

Program:

``` text
MOVI R1, 5
MOVI R2, 5
BEQ  R1, R2, target
MOVI R3, 111
target:
MOVI R3, 222
```

Expected:

``` text
R3 = 222
```

Inspect the PC waveform.

------------------------------------------------------------------------

## 100. Exercise: Force a Timing Question

Do not change RTL first.

Instead ask:

> If this CPU is synthesized for the Tang Primer 20K, what is the
> longest combinational path?

Likely candidates include arithmetic such as division.

The correct next tool is synthesis/timing analysis, not a guess from the
RTL source.

------------------------------------------------------------------------

# Part XXIV --- Where the CPU Ends and the SoC Begins

## 101. Freeze the CPU Interface

The CPU should be treated as a reusable processor once:

``` text
ISA is stable enough
I-BUS contract is stable
D-BUS contract is stable
parameter constraints are explicit
regressions pass
timing target is evaluated
```

Future subsystems should connect outside it.

------------------------------------------------------------------------

## 102. Next SoC Layer

A natural post-CPU roadmap is:

``` text
CPU
 |
 +-- I-BUS ----\
 |              \
 +-- D-BUS ------> system interconnect
                    |
                    +-- local BRAM
                    +-- DDR3 controller
                    +-- MMIO
                    +-- timers
                    +-- input controller
                    +-- GPU
                    +-- AI accelerator
```

As more masters appear---for example CPU instruction fetch, CPU data
access, GPU memory access, and AI DMA---the interconnect may require
arbitration.

That is a **SoC stage**, not a reason to reopen the CPU internals.

------------------------------------------------------------------------

# Part XXV --- Final Mental Model

The complete journey can be compressed into one picture:

``` text
                       SOFTWARE / PROGRAM
                              |
                              v
                       machine instructions
                              |
                              v
+------------------------------------------------------------------+
|                           LACOODA CPU                             |
|                                                                  |
|  +------+      +---------+      +----------+      +-----------+  |
|  |  PC  |----->| I-fetch |----->| decoder  |----->| control   |  |
|  +------+      +---------+      +-----+----+      +-----+-----+  |
|                                        |                 |        |
|                                        v                 v        |
|                                  +-----------+      +----------+  |
|                                  | register  |----->| datapath |  |
|                                  | file      |      | + ALU    |  |
|                                  +-----------+      +----+-----+  |
|                                                           |       |
|                                                    +------+-----+ |
|                                                    | branch /   | |
|                                                    | load/store | |
|                                                    +------+-----+ |
|                                                           |       |
+-----------------------------+-----------------------------+-------+
                              |                             |
                            I-BUS                         D-BUS
                              |                             |
==============================|=============================|========
                              |                             |
                    +---------v---------+          +--------v--------+
                    | instruction side |          | interconnect    |
                    | memory/system    |          | address decoder |
                    +------------------+          +--------+--------+
                                                           |
                                                   +-------+-------+
                                                   | data memory   |
                                                   | MMIO / DDR... |
                                                   +---------------+
```

And the timing mental model is:

``` text
STATE AT CLOCK EDGE
       |
       v
combinational propagation
       |
       +-- decode
       +-- register reads
       +-- muxes
       +-- ALU
       +-- comparisons
       +-- address calculations
       |
       v
if variable-latency external operation:
       wait using valid/ready
       |
       v
instruction completes
       |
       v
RETIREMENT CLOCK EDGE
       |
       +-- write register
       +-- update flags
       +-- update memory if accepted
       +-- advance/redirect PC
       |
       v
NEXT INSTRUCTION
```

If this model is clear, most of the code stops looking mysterious.

------------------------------------------------------------------------

# Appendix A --- Core SystemVerilog Patterns Used

## A.1 Continuous combinational assignment

``` systemverilog
assign y = a & b;
```

## A.2 Combinational process

``` systemverilog
always_comb begin
    y = '0;

    if (enable)
        y = a + b;
end
```

## A.3 Sequential state

``` systemverilog
always_ff @(posedge clk or posedge rst) begin
    if (rst)
        q <= '0;
    else if (enable)
        q <= d;
end
```

## A.4 Named port connections

``` systemverilog
child u_child (
    .clk   (clk),
    .rst   (rst),
    .input_a(parent_signal),
    .result(result_signal)
);
```

## A.5 Concatenation

``` systemverilog
assign word = {upper, lower};
```

## A.6 Replication

``` systemverilog
assign upper = {32{sign_bit}};
```

## A.7 Parameter-derived width

``` systemverilog
localparam int DATA_BYTES = DATA_WIDTH / 8;
```

## A.8 `$clog2`

``` systemverilog
localparam int REG_ADDR_WIDTH = $clog2(REG_COUNT);
```

For 64 registers:

``` text
$clog2(64) = 6
```

because six bits can address 64 values.

## A.9 Handshake

``` systemverilog
if (valid && ready) begin
    // transaction accepted
end
```

------------------------------------------------------------------------

# Appendix B --- Glossary

**ALU** --- Arithmetic Logic Unit. Performs arithmetic, logical, shift,
and comparison operations.

**Architectural state** --- State visible to software or defining CPU
execution, such as registers, PC, and flags.

**BRAM** --- FPGA block RAM, dedicated on-chip memory resources.

**Combinational logic** --- Logic whose outputs are functions of current
inputs rather than stored history.

**D-BUS** --- LACOODA data-side CPU interface for LOAD/STORE
transactions.

**Datapath** --- Hardware that carries and transforms instruction
operands and results.

**Decoder** --- Logic that interprets instruction fields and produces
control signals.

**Elaboration** --- Tool phase in which parameters, generate structures,
module hierarchy, widths, and connections are resolved.

**FPGA** --- Field-Programmable Gate Array.

**Handshake** --- Protocol in which sender and receiver explicitly agree
that a transfer occurred.

**I-BUS** --- LACOODA instruction-side CPU interface.

**Immediate** --- Constant encoded directly in an instruction.

**Interconnect** --- Hardware that routes transactions between masters
and slaves.

**ISA** --- Instruction Set Architecture.

**MMIO** --- Memory-Mapped I/O; devices controlled using ordinary
address-space accesses.

**PC** --- Program Counter.

**Port** --- A module's declared connection point.

**Register file** --- CPU storage array addressed by register
identifiers.

**Retirement** --- Point at which an instruction has completed
architecturally and the machine commits/moves beyond it.

**Sequential logic** --- Logic containing state updated on clock/event
boundaries.

**Signal** --- A value/wire used to connect hardware logic.

**Slave** --- Bus endpoint that responds to a master request.

**Master** --- Bus endpoint that initiates a request.

**Static timing analysis** --- Physical timing verification after
synthesis/place-route to determine whether clock constraints are met.

**Testbench** --- Simulation-only environment that drives and checks the
design under test.

**Valid/ready** --- Handshake convention where a transaction is accepted
when both signals are asserted.

**VCD** --- Value Change Dump waveform file.

------------------------------------------------------------------------

# Appendix C --- LACOODA Development Checklist

## CPU fundamentals

-   [ ] ALU operations verified
-   [ ] status flags verified
-   [ ] register file verified
-   [ ] R0 behavior verified
-   [ ] datapath verified

## ISA

-   [ ] instruction layout documented
-   [ ] instruction encoder verified
-   [ ] decoder legal encodings verified
-   [ ] illegal encodings suppress side effects
-   [ ] immediate extension verified

## Execution

-   [ ] CPU core integration verified
-   [ ] PC reset verified
-   [ ] sequential PC verified
-   [ ] branch redirect verified
-   [ ] signed/unsigned branch semantics verified

## Memory

-   [ ] LOAD effective address verified
-   [ ] STORE effective address verified
-   [ ] LOAD writeback verified
-   [ ] STORE data verified
-   [ ] alignment policy documented

## CPU boundary

-   [ ] I-BUS request held until ready
-   [ ] I-BUS address stable while waiting
-   [ ] fetched instruction buffered
-   [ ] D-BUS request held until ready
-   [ ] D-BUS payload stable while waiting
-   [ ] pause cannot abandon in-flight transaction
-   [ ] retirement advances PC exactly once

## Parameterization

-   [ ] architectural literals audited
-   [ ] root parameters identified
-   [ ] derived widths calculated
-   [ ] illegal combinations rejected
-   [ ] narrow immediate probe passes
-   [ ] large memory-map probe passes

## Repository/build

-   [ ] no duplicate RTL module definitions
-   [ ] no duplicate testbench module definitions
-   [ ] `run.sh --no-gui` passes
-   [ ] waveforms generated
-   [ ] recursive compilation/elaboration clean

## FPGA readiness

-   [ ] synthesize for target FPGA
-   [ ] inspect LUT/FF/BRAM/DSP use
-   [ ] run place-and-route
-   [ ] inspect critical path
-   [ ] confirm target clock timing
-   [ ] decide whether combinational multiply/divide need redesign

------------------------------------------------------------------------

# Appendix D --- What Comes After This Manual

The CPU journey is complete enough to begin the system journey.

A sensible continuation is:

``` text
1. Freeze CPU I-BUS/D-BUS interfaces.
2. Define complete SoC address map.
3. Add a proper interconnect policy.
4. Add MMIO.
5. Bring up simple GPIO/input.
6. Integrate external DDR3 controller.
7. Decide boot/loading path from flash or microSD.
8. Add 2D GPU command interface.
9. Add framebuffer/display path.
10. Run a minimal game loop.
11. Add OpenJoey2 rendering.
12. Add the dungeon-crawler workload.
13. Add AI inference accelerator only after the memory/bus architecture is stable.
```

The principle that should survive every future stage is:

> **Keep the CPU generic. Put system-specific acceleration around it.**

That is what allows LACOODA to become a reusable processor rather than a
single-purpose game circuit.

------------------------------------------------------------------------

# Closing

The most important thing built during this journey was not the ALU,
decoder, bus, or even the CPU.

It was the hardware mental model.

At the beginning, code such as:

``` systemverilog
decoder u_decoder (...);
datapath u_datapath (...);
```

naturally invites the software question:

> Which one executes first?

By the end, the better questions are:

``` text
What state exists?
What combinational paths exist between state elements?
Who drives this signal?
What consumes it?
When is state allowed to change?
What transaction is waiting?
What event means it completed?
What retires the instruction?
What changes the PC?
What widths are involved?
Does the physical path meet timing?
Where is the architectural boundary?
```

Those are hardware-design questions.

Once you start asking those automatically, SystemVerilog stops being
strange C-like syntax and starts becoming what it actually is: a
language for describing machines.
