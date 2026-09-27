# ADR 0004 — ExactRatio as the Public Exact-Scale Vocabulary

- Status: Accepted
- Date: 2026-09-27
- Decision scope: M1 exact Unit scale declaration

## Context

ADR 0002 requires every static Unit to expose an exact rational scale. R02
proved that normatively exact relationships can remain exact through
normalization, cross-cancellation and checked composition. R12 evaluated the
public/private boundary of that machinery.

User-defined Units need a stable way to declare exact scale relationships:

```d
struct InternationalFoot
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(381, 1250);
}
```

They do not, by that requirement alone, need a public general-purpose rational
arithmetic API.

R12 also corrected a limitation in the early R02 normalization probe. Signed
absolute-value logic is not valid for `long.min`; the final normalization
strategy carries magnitude through `ulong` and supports the full signed
`long` numerator range.

The R12 positive probe passes on DMD 2.111 and LDC 1.41, including sign
normalization, reduction, zero normalization, exact geospatial scales and
`long.min` numerator cases.

## Decision

M1 exposes a small compile-time type conceptually equivalent to:

```d
ExactRatio!(Numerator, Denominator)
```

as the public declarative vocabulary for exact Unit scale.

The public contract provides normalized compile-time numerator and denominator
values.

Ratio algebra implementation details—including GCD machinery,
cross-cancellation and checked composition—remain internal unless a separate
consumer later justifies promoting them.

## Normalization contract

For `ExactRatio!(N, D)`:

1. `D == 0` is invalid and rejected at compile time.
2. The normalized denominator is positive.
3. Numerator and denominator are reduced by their greatest common divisor.
4. Zero normalizes to `0/1`.
5. Equivalent ratios expose the same normalized numerator and denominator.
6. The full signed `long` numerator range, including `long.min`, is
   supported.
7. Normalization must not evaluate an unrepresentable `-long.min`.
8. If a normalized denominator cannot be represented as positive `long`, the
   declaration is rejected.
9. If a normalized numerator cannot be represented in `long`, the
   declaration is rejected.

For M1, numerator and denominator storage/types are compile-time `long`
values.

## Examples

```text
ExactRatio!(2, 4)        ->  1/2
ExactRatio!(-2, -4)      ->  1/2
ExactRatio!(1, -2)       -> -1/2
ExactRatio!(0, -37)      ->  0/1
ExactRatio!(381, 1250)   -> 381/1250
ExactRatio!(1200, 3937)  -> 1200/3937
```

The two geospatial foot definitions remain exact and distinct.

## Public boundary

### Public

The library may expose:

- the `ExactRatio` template/type;
- normalized `numerator`;
- normalized `denominator`.

These are sufficient for users to define custom exact Units.

### Internal

The following remain implementation details in M1:

- GCD implementation;
- signed-magnitude helpers;
- ratio multiplication/division helpers;
- cross-cancellation strategy;
- overflow-check helpers;
- conversion-specific composition machinery.

Keeping these internal avoids accidentally committing quantities-d to a broad
public rational-number API.

## Consequences

### Positive

- Custom Unit authors have a stable exact declaration vocabulary.
- Exact geospatial scales remain exact at compile time.
- Equivalent ratios normalize to one canonical representation.
- The design handles `long.min` correctly.
- Public API surface remains small.
- Internal ratio algebra can evolve without becoming source compatibility
  surface.

### Costs

- M1 exact scale range is bounded by normalized signed `long`
  numerator/denominator representability.
- Very large exact ratios may require future extension or a different internal
  representation.
- Consumers that want general rational arithmetic cannot assume
  `ExactRatio` provides it.

## Alternatives considered

### Keep ExactRatio entirely private

Rejected. User-defined Units need a public, stable way to express exact scale
without depending on private implementation details.

### Expose a full rational arithmetic API

Rejected for M1. No current consumer requires a generic rational-number
library, and doing so would unnecessarily enlarge the compatibility surface.

### Store floating scale constants

Rejected. Normatively exact Unit relationships must not be replaced by
approximate decimal constants.

## Not decided by this ADR

This ADR does not freeze:

- final module location;
- whether convenience aliases/helpers are exposed;
- ratio arithmetic APIs;
- derived-dimension scale algebra;
- conversion function names;
- rounding policy surface;
- runtime unit metadata.

Those remain separate decisions.

## Evidence

R02 established:

- exact rational Unit definitions;
- normalization/cross-cancellation;
- checked remaining multiplication;
- separation of Unit algebra from value conversion.

R12 confirms on both DMD 2.111 and LDC 1.41:

- sign normalization;
- GCD reduction;
- zero -> 0/1;
- exact international-foot and US-survey-foot scales;
- `long.min` numerator support;
- compile-time rejection of invalid denominator cases.

The research probe remains under
`research/r12-exact-ratio-boundary/`.
