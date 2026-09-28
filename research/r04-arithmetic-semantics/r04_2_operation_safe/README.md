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
