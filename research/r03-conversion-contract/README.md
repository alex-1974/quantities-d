# R03 — Conversion contract probe

Research-only M1 probe. No names in this experiment are public API.

## Goal

Define conversion semantics after ADR 0001–0004 without conflating two
questions:

1. What is the exact mathematical Unit-to-canonical scale?
2. Can the resulting value be represented by the target Rep under the caller's
   requested conversion intention?

## Conversion intentions under test

### Exact-required

Return a value only if the mathematical result is exactly representable by the
target Rep. Inexact and overflow are distinct failures.

### Checked / loss-aware

Return status plus value where meaningful. The caller can distinguish:

- exact;
- inexact;
- overflow.

No rounding is silently selected.

### Explicit-rounded

For integral targets, the caller explicitly selects a rounding rule when the
mathematical result is fractional.

Initial research modes:

- toward zero;
- floor;
- ceiling;
- nearest, ties away from zero.

These names and the final public surface are not yet selected.

## Required cases

- 1 km -> long metre = 1000, exact;
- 1 m -> long metre = 1, exact;
- 1 mm -> long metre = inexact;
- 1500 mm -> long metre = inexact;
- explicit rounding for positive and negative fractional results;
- exact foot conversions where the target integer happens to be representable;
- overflow is distinct from inexact;
- full signed long source range remains safe;
- floating targets retain exact rational scale until final floating arithmetic.

## Design boundary

Unit scale remains exact rational metadata. Conversion policy operates on
values and Reps. Rounding is never encoded in Unit identity.

The probe intentionally does not decide implicit conversions, mixed-unit
arithmetic, public function names, floating narrowing, or exception policy.


## First probe result — 2026-09-27

The initial signed-long conversion probe builds, links and runs successfully on
both baseline compilers:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

Confirmed so far:

- exact/inexact/overflow are separable;
- cross-cancellation avoids needless overflow;
- full signed long source range is handled safely;
- explicit positive/negative rounding modes behave as intended;
- exact rational scale is retained until final floating arithmetic.

A representative Rep matrix is the next gate before promotion.
