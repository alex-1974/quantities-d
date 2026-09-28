# R04.2.9 — Integral Class-W code-generation gate

## Goal

Compare Quantity-shaped Class-W integral arithmetic against equivalent raw D
arithmetic with the same explicit operation-safe widening.

The semantic and attribute gates have already passed. This probe asks only
whether the wrapper leaves abstraction overhead in optimized machine code.

## Pairs

- int + uint -> long;
- uint - uint -> long;
- uint * uint -> ulong;
- int Quantity * uint scalar -> long;
- uint scalar * int Quantity -> long.

Each raw function explicitly casts operands to the ResultRep selected by the
R04.2.7 policy. Each Quantity function performs the same operation through the
wrapper.

## Acceptance

For each pair inspect the exposed extern(C), noinline function body.

A passing result has the same essential integer arithmetic/conversion cost and
contains no surviving:

- Quantity storage operation beyond the scalar ABI value;
- allocation;
- metadata lookup;
- wrapper helper call.

Instruction spelling or register allocation need not be byte-identical.

This is a scoped zero-overhead claim for the measured compiler/version,
optimization mode and x86_64 target.


## Observed result — x86_64 baseline

### LDC 1.41, -O3 -release

All five raw/Quantity pairs are instruction-identical in the relevant exposed
function bodies:

- int + uint -> long;
- uint - uint -> long;
- uint * uint -> ulong;
- int Quantity * uint scalar -> long;
- uint scalar * int Quantity -> long.

No wrapper helper call, metadata work, allocation or extra storage survives.

**LDC code-generation gate: PASS.**

### DMD 2.111, -O -release -inline

The arithmetic itself lowers to the same widening and integer operations, but
the Quantity-shaped functions retain additional stack traffic:

- binary Quantity operations spill both scalar fields to stack and reload them;
- scalar multiplication spills the Quantity field and restores a register with
  push/pop.

The raw functions do not contain this traffic.

Examples:

- rawAddIU: sign-extend + move + add + ret;
- quantityAddIU: stack allocation + two stores + reloads + same add + stack
  restore + ret.

Likewise for subtraction and multiplication.

There are no wrapper helper calls, allocations or metadata lookups, but the
extra stack operations are real generated-code overhead at this measured ABI
boundary.

**DMD strict zero-overhead code-generation gate: FAIL for this probe.**

## Interpretation

This result does not invalidate the R04.2.7 arithmetic policy or the R04.2.8
semantic promotion gate. It establishes a compiler-specific lowering
difference for the research wrapper.

Current evidence therefore supports:

- portable Class-W arithmetic semantics;
- LDC 1.41 x86_64 optimized-release zero-overhead for the measured pairs;
- DMD 2.111 x86_64 optimized-release semantic equivalence, but not strict
  instruction/storage equivalence for the measured wrapper ABI.

Do not generalize the DMD result yet to inlined call sites. These functions are
deliberately extern(C) and noinline so that wrapper lowering remains visible at
a function boundary.

## Next question

Before changing the public design, distinguish:

1. ABI-boundary cost of passing a one-field struct by value;
2. cost that survives when Quantity arithmetic is inlined into a normal caller.

A follow-up code-generation probe should compare realistic inlined call sites.
If the stack traffic disappears after inlining, the public zero-overhead claim
must be scoped to optimized inlined use rather than noinline ABI boundaries.
