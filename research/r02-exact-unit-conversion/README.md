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


## Conversion-intent probe result

The three-intent probe passes on DMD 2.111 and LDC 1.41.

The evidence supports distinct caller intentions rather than one conversion
operation with hidden behavior:

- checked/loss-aware conversion reports exact, inexact or overflow;
- exact-required conversion rejects a result that is not exactly representable;
- explicit-rounded conversion requires a caller-selected rounding rule.

The probe demonstrated toward-zero, floor, ceiling and nearest with an explicit
ties-away-from-zero rule. Those particular names and rounding modes are not yet
selected public API. Their purpose was to prove that rounding policy can remain
orthogonal to the exact unit relationship.

## R02 contract candidate

R02 now has sufficient evidence for the following M1 design constraints:

1. A normatively exact unit relationship is represented exactly at compile time,
   using a rational scale rather than an approximate decimal.
2. Rational scale algebra normalizes ratios and cross-cancels before
   multiplication.
3. Integer overflow/representability is checked before the remaining
   multiplication is evaluated.
4. Unit algebra and value/Rep conversion are separate layers.
5. Integral conversions must never silently truncate, wrap or round.
6. Conversion intent must make potential loss visible.
7. Rounding, where offered, is an explicit caller-selected value-conversion
   policy and is not part of Unit identity.
8. Floating conversion should retain the exact rational scale until the final
   floating arithmetic.
9. Full signed integral ranges, including `long.min`, must be supported without
   undefined or unrepresentable absolute-value steps.

Still open outside this R02 conclusion:

- the final public conversion names/signatures;
- which rounding modes belong in the minimal public core;
- generic support beyond the probe's `long` and `double`;
- B versus C storage/type identity from R01;
- compile-time and code-generation cost;
- affine conversions/quantity points.

## Consequence for R01

R02 removes one major uncertainty around canonical storage candidate C:
canonicalization does not inherently require silent loss. A C-style boundary can
reject, report or explicitly round a source-to-canonical conversion according to
the same policy demonstrated here.

It also confirms that B does not avoid conversion policy: mixed-unit arithmetic
or explicit conversion between B quantities requires the same exactness,
overflow and rounding decisions.

Therefore conversion safety alone does not select B or C. The remaining
discriminators are primarily public type/boundary semantics and measured cost.
