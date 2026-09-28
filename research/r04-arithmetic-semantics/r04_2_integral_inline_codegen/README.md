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
