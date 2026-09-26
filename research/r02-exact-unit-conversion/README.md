# R02 — Exact unit representation and conversion

Research-only probe for quantities-d issue #2.

## First question

Can exact linear-unit definitions be represented and composed at compile time
without storing runtime unit metadata or prematurely converting scale factors to
floating point?

Reference units:

- metre: 1 m
- kilometre: 1000 m
- international foot: exactly 381/1250 m
- US survey foot: exactly 1200/3937 m

The first probe deliberately tests unit algebra only. Quantity representation,
integer/floating conversion, rounding and overflow policy remain subsequent
steps.

No code in this directory is proposed public API.


## Confirmed probe results

The probes pass on both baseline compilers, DMD 2.111 and LDC 1.41.

Current evidence supports the following separation:

1. Unit definitions can retain exact rational relationships at compile time.
2. Rational composition should cross-cancel before multiplication.
3. Remaining products require explicit representability checks.
4. Integral value conversion is a separate concern from unit definition.
5. Integral conversion can distinguish exact, inexact and overflow without
   silently truncating.
6. Signed conversion can cover the full `long` range, including `long.min`,
   by carrying magnitude as `ulong` rather than applying `abs(long.min)`.
7. Floating conversion can retain the exact rational unit scale until the final
   floating arithmetic.

These results do not yet select B or C from R01. They establish machinery and
policy constraints that both representations would need.

## Conversion-policy boundary

The next design question is not another unit special case. It is which
conversion intentions must be distinct in the public API.

The current working taxonomy is:

- **exact-required** — succeed only when the target representation can express
  the mathematical result exactly;
- **checked/loss-aware** — report whether conversion is exact, inexact or
  unrepresentable/overflowing;
- **explicit-rounded** — the caller deliberately supplies a rounding policy for
  a conversion that may not be integral.

Rounding is a caller/value-conversion policy. It must not be hidden in the unit
definition itself.

This taxonomy is a research hypothesis for the next probe, not yet public API.
