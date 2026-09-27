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


## Representative Rep matrix result — 2026-09-27

The extended representative Rep matrix builds, links and runs successfully on
both baseline compilers:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

Covered classes:

- integral -> integral;
- integral -> floating;
- floating -> integral;
- floating -> floating.

Representative Reps include `int`, `long`, `float`, `double`, and
`real`.

### Interpretation

The compiler/language mechanics do not require separate public conversion
models per representative Rep family.

However, the term "exact" must be used carefully for floating sources. Once a
physical value is already represented by a binary floating-point value, the
library cannot recover whether that source value was itself an exact
representation of the originating physical quantity.

For floating-source conversions, R03 therefore distinguishes:

1. **source-value preservation / representability** — whether the existing
   floating value can be converted to the target representation without an
   additional representational change beyond the requested Unit transform; and
2. **physical/mathematical exactness of the original measurement** — not
   inferable by quantities-d from the floating value alone.

This prevents an `exact` status from making a stronger epistemic claim than
the representation supports.


## Status and rounding semantics candidate

R03 keeps the status term `exact`, but defines it narrowly.

`exact` means:

> the requested conversion of the represented source value to the target Unit
> and Rep requires no information-losing rounding or truncation by the
> conversion operation.

It does **not** mean:

- that the original physical measurement was exact;
- that a floating source exactly represented some prior decimal or physical
  value;
- that the target floating value has infinite mathematical precision.

This definition is stronger and more useful than `representable`: a
fractional mathematical result can be mapped to an integral target type only by
rounding, even though some integral value is trivially representable.

### Candidate status set

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow
}
```

Semantics:

- `exact`: conversion introduces no information-losing rounding/truncation;
- `inexact`: the mathematical conversion result cannot be represented under
  the requested policy without rounding or other representational loss;
- `overflow`: the required result is outside the supported target
  representation/range.

The status describes the conversion outcome, not caller intent.

### Candidate rounding policy

```d
enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAway
}
```

Rounding is only selected explicitly by the caller. Unit identity never carries
a rounding policy.

A rounded result may still carry `inexact` status: the returned value is the
explicitly requested rounded value, while the status records that the
unrounded mathematical result was not exactly representable.

### Important separation

```text
conversion intent     result status
------------------    ----------------
exact-required   -->  value or exact/inexact/overflow failure
checked          -->  exact/inexact/overflow observation
rounded(mode)    -->  rounded value + exact/inexact/overflow status
```

This keeps policy and observation orthogonal.
