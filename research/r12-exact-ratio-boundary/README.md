# R12 — ExactRatio public boundary and normalization

Research-only M1 probe.

## Question

R02 established exact rational unit scales, normalization, cross-cancellation
and checked composition. ADR 0002 requires Unit to expose an exact rational
scale. What part of that mechanism should be public?

## Candidate

Expose one small declarative compile-time type:

```d
ExactRatio!(Numerator, Denominator)
```

for Unit authors.

Keep ratio algebra, GCD implementation, cross-cancellation and checked
composition as implementation details unless a separate consumer later
justifies a public rational-arithmetic API.

## Important correction from R02

The early R02 normalization probe used signed `absLong`. That is not valid for
`long.min`. Later R02 conversion work already established the correct pattern:
carry signed magnitude through an unsigned representation rather than evaluating
`-long.min`.

R12 therefore requires normalization itself to support the full signed
`long` numerator range.

## Required properties

- denominator zero is rejected at compile time;
- denominator is normalized positive;
- numerator/denominator are reduced by GCD;
- zero normalizes to 0/1;
- `long.min` numerator is supported;
- normatively exact geospatial scales remain exact;
- normalized identity is stable: equivalent ratios expose equal numerator and
  denominator values;
- no runtime storage is required;
- public surface need not expose arithmetic helpers.

## API-boundary hypothesis

`ExactRatio` is justified as public because user-defined Unit declarations
need a stable vocabulary for exact scale:

```d
struct InternationalFoot
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(381, 1250);
}
```

The public contract is the normalized ratio type and its normalized
numerator/denominator values. Arithmetic implementation details remain private.


## Probe result — 2026-09-27

The R12 probe builds, links and runs successfully on both supported baseline
compilers:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

Confirmed cases include ratio reduction, denominator sign normalization,
zero-to-0/1 normalization, exact international-foot and US-survey-foot scales,
and full signed numerator handling including `long.min`.

R12 therefore supports promotion of the small public ExactRatio declaration
vocabulary while keeping ratio algebra internal. See ADR 0004.
