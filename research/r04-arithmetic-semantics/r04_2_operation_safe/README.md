# R04.2.3 — Integral operation-safe widening

## Goal

Determine where a normal built-in D integer ResultRep can represent the complete
mathematical result range of an operation.

This is stricter than R04.2.2 operand-safe common Rep.

The probe covers:

- addition;
- subtraction;
- multiplication.

It answers only whether widening can make an operation universally overflow-free
for a Rep pair. It does not yet choose public overflow behavior for pairs where
no such built-in type exists.

## Range formulas

For operand ranges [Amin, Amax] and [Bmin, Bmax]:

Addition:
- min = Amin + Bmin
- max = Amax + Bmax

Subtraction:
- min = Amin - Bmax
- max = Amax - Bmin

Multiplication:
- extrema are among:
  - Amin * Bmin
  - Amin * Bmax
  - Amax * Bmin
  - Amax * Bmax

The research implementation evaluates these ranges with compile-time BigInt so
the analysis itself does not overflow while studying built-in integer types.

## Candidate output

For each pair and operation:

- smallest built-in integer type containing the complete result range; or
- none, when no normal built-in type is sufficient.

This separates the zero-runtime-check subset from operations that necessarily
need an explicit overflow policy.


## Observed result — DMD 2.111 / LDC 1.41, x86_64

Both baseline compilers produced the same operation-safe widening matrix:

| A | B | + | - | * |
|---|---|---|---|---|
| byte | byte | short | short | short |
| ubyte | ubyte | short | short | ushort |
| byte | ubyte | short | short | short |
| short | short | int | int | int |
| ushort | ushort | int | int | uint |
| short | ushort | int | int | int |
| int | int | long | long | long |
| uint | uint | long | long | ulong |
| int | uint | long | long | long |
| int | long | none | none | none |
| uint | long | none | none | none |
| long | long | none | none | none |
| uint | ulong | none | none | none |
| int | ulong | none | none | none |
| long | ulong | none | none | none |
| ulong | ulong | none | none | none |

## R04.2.3 conclusion

A clean zero-runtime-overflow-check subset exists.

For the tested built-in integer families, all combinations whose operands are at
most 32 bits can be widened to a normal built-in type that contains the complete
mathematical result range for +, -, and *.

Examples:

- byte/byte +,-,* -> short;
- short/short +,-,* -> int;
- int/int +,-,* -> long;
- uint/uint +,- -> long, * -> ulong;
- int/uint +,-,* -> long.

Once a 64-bit operand participates, the tested operations no longer have a
normal built-in ResultRep that is universally result-safe.

This creates a useful semantic boundary:

### Class W — statically operation-safe widening

The operator can return a plain Quantity with a widened integral Rep and does
not need runtime overflow reporting.

### Class O — overflow-capable wide arithmetic

No built-in Rep can represent every mathematical result. A public operator must
therefore choose an explicit overflow policy, or not exist.

This distinction is preferable to applying runtime checked arithmetic to every
integral operation.

## Next decision

Evaluate whether M3 should:

1. expose direct integral operators only for Class W;
2. additionally expose named checked arithmetic for Class O;
3. expose direct operators for Class O with a checked result type;
4. defer Class O entirely until a concrete consumer requires it.

The decision should be based on API consistency, ergonomics, attributes, code
generation, and real consumer need.
