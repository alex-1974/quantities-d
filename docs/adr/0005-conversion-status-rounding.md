# ADR 0005 — Conversion Status and Explicit Rounding Semantics

- Status: Accepted
- Date: 2026-09-27
- Decision scope: M1 conversion semantics

## Context

ADR 0001 selects canonical Quantity storage. ADR 0004 preserves exact Unit
scales as compile-time rational metadata. Conversion therefore crosses two
independent boundaries:

1. exact mathematical Unit scaling; and
2. representability in the target Rep.

R02 established that integral conversions must not silently truncate, wrap or
round. R03 validated the conversion model on DMD 2.111 and LDC 1.41 across
representative `int`, `long`, `float`, `double` and `real` paths.

R03 also identified an important semantic limit: for a floating source,
quantities-d sees the represented floating value. It cannot infer whether that
value exactly represented an earlier physical measurement or decimal source.

## Decision

M1 distinguishes conversion **status** from conversion **intent**.

The status model is conceptually:

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow
}
```

The names are part of the semantic decision; exact final public spelling and
module placement may still be adjusted before API stabilization.

## Meaning of exact

`exact` means:

> The requested conversion of the represented source value to the target Unit
> and Rep introduces no information-losing rounding or truncation by the
> conversion operation.

It does not claim that:

- an original physical measurement was exact;
- a floating source exactly represented an earlier decimal or physical value;
- a floating target has infinite mathematical precision.

Thus `exact` is a property of the requested conversion relative to the
represented source value.

## Status semantics

### exact

No information-losing rounding or truncation is required by the requested
conversion.

### inexact

The unrounded mathematical conversion result cannot be represented under the
requested target/policy without representational loss.

### overflow

The required result is outside the supported target representation or range.

Overflow is distinct from inexactness.

## Conversion intent

M1 supports three conceptual caller intentions.

### Exact-required

The caller requires an exact conversion. Inexactness or overflow is reported as
failure; no implicit rounding is performed.

### Checked / loss-aware

The caller requests observation of conversion status and can distinguish exact,
inexact and overflow outcomes.

### Explicit-rounded

For a conversion requiring integral rounding, the caller explicitly selects a
rounding mode.

The initial M1 rounding vocabulary is:

```d
enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAway
}
```

A rounded conversion may return an `inexact` status together with the rounded
value. The value records the requested policy result; the status records that
the unrounded result was not exactly representable.

## Normative constraints

1. Unit scale and value-conversion policy are separate.
2. Normatively exact Unit scales remain exact rational metadata until the value
   conversion requires a target representation.
3. Integral conversion must never silently truncate, wrap or round.
4. Potentially lossy conversion requires an explicit caller-visible intent.
5. Overflow and inexactness are distinct outcomes.
6. Rounding is caller-selected and is not part of Unit identity.
7. Rounded results preserve whether rounding was actually required.
8. Signed integral conversion must support the full source range, including
   `long.min`, without unsafe signed absolute-value operations.
9. Cross-cancellation should occur before checked integral multiplication where
   it avoids needless intermediate overflow.
10. Floating-source `exact` status is relative to the represented floating
    source value and must not be documented as measurement exactness.
11. Exact public operation names/signatures are not fixed by this ADR.

## Representative evidence

R03 validates on both baseline compilers:

- integral -> integral;
- integral -> floating;
- floating -> integral;
- floating -> floating.

Representative Reps:

- `int`;
- `long`;
- `float`;
- `double`;
- `real`.

Tested behavior includes:

- 1 km -> integral metre exactly;
- fractional millimetre -> integral metre as inexact;
- exact integral boundary cases;
- positive and negative explicit rounding;
- overflow distinct from inexact;
- full signed `long` source handling;
- exact rational scale retained until final floating arithmetic.

## Consequences

### Positive

- No silent unit-conversion truncation.
- Callers can make loss policy explicit.
- Status remains useful across integral and floating Rep families.
- Floating values are not given a false claim of physical exactness.
- Rounding policy remains orthogonal to Unit and Quantity identity.

### Costs

- Conversion APIs require more explicit surface than a simple cast.
- Floating exactness documentation must remain carefully scoped.
- Generic unsigned-wide and floating-narrowing details still require
  implementation work.

## Not decided by this ADR

This ADR does not freeze:

- exact public conversion function names;
- return container/error mechanism;
- exception versus non-throwing convenience layers;
- implicit conversion policy;
- mixed-unit arithmetic syntax;
- generic unsigned types wider than signed-long-backed research paths;
- detailed floating narrowing policy;
- affine quantity-point conversions.

These require separate API/implementation decisions.

## Evidence location

Research remains under `research/r03-conversion-contract/`.
