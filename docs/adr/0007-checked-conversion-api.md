# ADR 0007 — Checked, Exact, and Rounded Conversion API

- Status: Proposed
- Date: 2026-09-27
- Research: R14 — Checked Conversion API
- Issue: #8
- Supersedes: none
- Related: ADR 0001, ADR 0004, ADR 0005, ADR 0006

## Context

ADR 0001 establishes canonical `Quantity!(Spec, Rep)` storage. ADR 0004
establishes exact rational unit scales. ADR 0005 requires caller-visible intent
for potentially lossy conversion, distinguishes exactness from overflow, and
forbids silent integral truncation or rounding. ADR 0006 requires CTFE- and
UFCS-friendly public construction and extraction.

The first M1 static quantity core deliberately rejects all non-canonical unit
construction and extraction until a checked conversion API exists.

R14 evaluated candidate API shapes and conversion kernels on DMD 2.111 and
LDC 1.41, including integral and binary64 floating-point paths.

## Decision

### 1. Public conversion vocabulary

M1 uses named operations that express caller intent directly:

```d
q.checkedIn!Unit
q.exactIn!Unit
q.roundedIn!(Unit, RoundingMode.floor)

value.checkedQuantity!(Spec, Unit)
value.exactQuantity!(Spec, Unit)
value.roundedQuantity!(Spec, Unit, RoundingMode.floor)
```

Equivalent function-call syntax remains available through normal D UFCS rules.

### 2. Checked conversion status

Checked conversion reports:

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}
```

Meanings:

- `exact`: converting the represented source value with the exact rational unit
  scale introduces no representational loss in the requested target Rep.
- `inexact`: the mathematical result is representable only after information-
  losing rounding or truncation.
- `overflow`: a finite represented source and exact scale produce a result
  outside the supported target representation/range.
- `nonFinite`: the floating source is NaN or infinity and lies outside the
  ordinary finite quantity-conversion contract.

### 3. Exact-required conversion

Exact-required conversion returns an invariant-owning `ExactResult!T`.

The result type:

- exposes a value only on exact success;
- distinguishes `inexact`, `overflow`, and `nonFinite` failures;
- owns its state invariants through private representation and explicit
  constructors/accessors;
- remains allocation-free and CTFE-compatible.

M1 does not require an overlapping union representation.

### 4. Integral conversion

Integral unit conversion:

- retains exact rational scale until target representation;
- cross-cancels before checked multiplication;
- supports the full signed integral range, including `long.min`;
- distinguishes exact, inexact, and overflow;
- never silently truncates, wraps, or rounds;
- uses explicit caller-selected rounding for inexact integral results.

M1 rounding modes are:

```d
enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAway
}
```

Source/target unit ratio composition must itself be overflow-safe and must
cross-cancel before forming intermediate products.

### 5. Floating-to-floating conversion

Floating exactness is relative to the **represented source floating value**,
not an earlier decimal spelling or physical measurement.

A floating-to-floating conversion is `exact` iff applying the exact rational
unit scale to the represented source value yields a mathematical result exactly
representable in the target floating Rep.

Round-trip or inverse-operation equality is not a valid exactness test.

Integer-style `RoundingMode` is not applied to floating-to-floating conversion.
The conversion reports whether representation rounding was required.

NaN and infinities are reported as `nonFinite`, not `overflow`.

### 6. CTFE and UFCS

Representative checked/exact/rounded construction and extraction operations must
work in CTFE and remain natural under UFCS.

A runtime-only bit reinterpretation path is insufficient where the public
operation promises CTFE. The production implementation must use CTFE-compatible
logic or provide an equivalent CTFE path with identical semantics.

### 7. Shared semantics, implementation freedom

Construction and extraction share the same conversion semantics and may share
internal kernels. The public named operations are intentionally distinct so that
caller intent remains visible.

This ADR does not freeze:

- module placement;
- internal kernel decomposition;
- result-layout micro-optimizations;
- generalized `float` / `real` implementation details beyond validated
  semantics;
- mixed integral/floating Rep policy;
- exact diagnostics wording.

## Alternatives considered

### One operation plus policy enum

Rejected for M1 because ordinary call sites expose more policy machinery without
a demonstrated reduction in conceptual complexity.

### Independent named implementations

Rejected because checked, exact-required, and rounded semantics could drift.

### Public aggregate exact result

Rejected because callers could construct contradictory states and read a value
from failed conversions.

### Round-trip floating exactness

Rejected because floating rounding can be masked by the inverse operation.
Represented binary64 `0.1 * 10` is a concrete counterexample.

### Treat non-finite input as overflow

Rejected because pre-existing NaN/infinity and arithmetic range overflow are
materially different failure classes.

## Consequences

- The M1 production core can safely enable non-canonical unit construction and
  extraction without heuristic unit inference.
- Caller intent remains explicit at public boundaries.
- Strong quantities can normalize to scalar kernels without weakening conversion
  semantics.
- Integral conversion requires careful checked arithmetic and exact ratio algebra.
- Floating exactness requires more work than ordinary arithmetic equality.
- CTFE remains a real implementation constraint, not only an API-style goal.
- Result temporaries may carry small status overhead; `Quantity` storage remains
  exactly the Rep payload where the language permits.

## Validation evidence

R14 research validated the selected direction with eight unittest modules on:

- DMD 2.111;
- LDC 1.41.

The matrix covered:

- CTFE and UFCS API forms;
- exact/inexact/overflow/nonFinite status propagation;
- `long.min`;
- cross-cancellation;
- overflow-safe unit-ratio composition;
- all M1 integral rounding modes;
- binary64 normal, negative, subnormal, precision, exponent, overflow, NaN and
  infinity cases.

Promotion to **Accepted** requires a production implementation slice and the
normal quantities-d gates, including compile-negative and external-consumer
validation.
