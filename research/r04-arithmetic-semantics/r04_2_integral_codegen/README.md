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
