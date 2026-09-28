# R04.2.10 — Integral Class-W inlined-caller code-generation gate

## Goal

Distinguish ABI-boundary wrapper cost from optimized hot-path cost.

R04.2.9 deliberately passed Quantity wrappers through extern(C), noinline
function boundaries. LDC eliminated the wrapper completely; DMD 2.111 retained
stack spills.

This probe instead keeps only the externally visible measurement functions
noinline. The Quantity construction and arithmetic live in normal inlineable D
functions and templates inside those callers.

## Pairs

- int + uint -> long;
- uint - uint -> long;
- uint * uint -> ulong;
- int Quantity * uint scalar -> long;
- uint scalar * int Quantity -> long.

Raw and Quantity callers receive the same scalar ABI arguments.

## Acceptance

After optimized release compilation, compare each raw/Quantity caller pair.

A strict pass requires no additional hot-path instructions attributable to:

- Quantity construction/storage;
- field spills/reloads;
- wrapper helper calls;
- allocation;
- metadata operations.

Register allocation or equivalent instruction spelling may differ if the
essential operation count is unchanged.

## Interpretation

If DMD passes here while failing R04.2.9, the measured overhead is an
ABI-boundary property of passing the one-field struct by value, not an inherent
cost of optimized Quantity arithmetic.

Any zero-overhead statement must remain scoped to the compiler/version,
optimization mode and target actually measured.


## Observed result — x86_64 baseline

### DMD 2.111, -O -release -inline

All five raw/Quantity caller pairs are instruction-identical:

- int + uint -> long;
- uint - uint -> long;
- uint * uint -> ulong;
- int Quantity * uint scalar -> long;
- uint scalar * int Quantity -> long.

No Quantity construction, field spill/reload, wrapper helper call, allocation or
metadata operation survives in the measured caller bodies.

**DMD inlined-caller code-generation gate: PASS.**

### LDC 1.41, -O3 -release

All five raw/Quantity caller pairs are likewise instruction-identical.

**LDC inlined-caller code-generation gate: PASS.**

## Interpretation

Together with R04.2.9 this isolates the DMD 2.111 discrepancy:

- passing the one-field Quantity struct itself through a forced noinline
  extern(C) boundary caused additional stack traffic in DMD;
- when the public ABI remains scalar and Quantity construction/arithmetic is
  inlineable inside the optimized caller, DMD removes the wrapper completely;
- LDC removed the wrapper in both probes.

Therefore the measured Class-W arithmetic itself has no surviving runtime
abstraction cost in optimized inlined use on both baseline compilers.

The stronger ABI-boundary claim is compiler-specific:

- LDC 1.41: zero additional wrapper cost in the measured noinline struct ABI
  probe;
- DMD 2.111: extra stack traffic at that forced struct ABI boundary.

## R04.2 code-generation conclusion

For x86_64 optimized release builds on the current baseline:

> Class-W Quantity arithmetic can compile to the same instructions as explicit
> raw widened integer arithmetic when the operations are inlineable.

This statement is intentionally scoped. It does not claim identical code at
every ABI boundary, optimization level, compiler version or architecture.
