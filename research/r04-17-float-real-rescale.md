# R04.17 — Nontrivial float and real rescale

**Issue:** #37  
**Status:** Active research  
**Base:** develop@30c9e77537276a8c83ebcac93cd83bd80688fb7d

## Scope

R04.17 asks whether the accepted represented-source exact-rescale contract can
extend beyond binary64.

The investigation deliberately separates:

- `float` / IEEE binary32, whose format is fixed by D;
- `real`, whose representation is implementation-defined.

No production API change is implied by this branch.

## Probe 1 — compiler/target property matrix

The first probe records `sizeof`, `alignof`, `mant_dig`, `min_exp`, and
`max_exp` for `float`, `double`, and `real` under the baseline compilers.

This establishes what the current x86-64 CI actually provides without turning
that target observation into a portable `real` contract.

## Probe 2 — binary32 structural width bounds

A finite represented binary32 operand has at most 24 significand bits.

The exact public scale magnitude is bounded by positive signed-64-bit
`ExactRatio` components, i.e. at most 63 magnitude bits.

Before any cancellation, therefore:

```text
product:
    significand(lhs) * significand(rhs) * scaleNumerator
    <= 24 + 24 + 63
    <= 111 bits

quotient:
    numerator   <= 24 + 63 = 87 bits
    denominator <= 24 + 63 = 87 bits
```

Cross-cancellation can only reduce these widths.

If validated against actual decomposition/oracle results, binary32 product and
quotient therefore need no UInt192 fallback; a two-limb 128-bit exact kernel is
structurally sufficient.

## Probe 3 — binary64 reuse would double-round binary32

A tempting implementation is:

```text
float operands
    -> exact binary64 kernel
    -> correctly rounded double
    -> cast to float
```

That is not generally equivalent to one final binary32 rounding.

Construct:

```text
scale = 1 + 2^-24 + 2^-60
      = (2^60 + 2^36 + 1) / 2^60

lhs = 1.0f
rhs = 1.0f
```

The exact result is slightly above the midpoint between `1.0f` and its next
binary32 neighbor, so correct once-rounded binary32 must select the upper
neighbor.

Correct binary64 rounding first loses the `2^-60` term and lands exactly on
the binary32 midpoint. Casting that midpoint to float then ties-to-even to the
lower value `1.0f`.

Therefore a production binary32 contract requires a direct binary32 quantizer;
the accepted binary64 kernel cannot simply be reused followed by a cast.

## Next probes

- exact binary32 decomposition and quantizer;
- independent rational oracle validation;
- IEEE special values;
- CTFE represented-source boundary;
- performance/codegen;
- separate real-format policy.


## Probe 1 results

Both baseline compilers on the current Ubuntu x86-64 runner report:

```text
float:
    sizeof   = 4
    alignof  = 4
    mant_dig = 24
    min_exp  = -125
    max_exp  = 128

double:
    sizeof   = 8
    alignof  = 8
    mant_dig = 53
    min_exp  = -1021
    max_exp  = 1024

real:
    sizeof   = 16
    alignof  = 16
    mant_dig = 64
    min_exp  = -16381
    max_exp  = 16384
```

The observed `real` is therefore the x86 extended-precision family, but this
is target evidence only and is not promoted as a portable D `real` contract.

## Probe 2 result

The structural binary32 bounds are confirmed:

```text
product numerator       <= 111 bits
quotient numerator      <= 87 bits
quotient denominator    <= 87 bits
```

A two-limb 128-bit exact representation is sufficient for both product and
quotient. Unlike binary64 product, binary32 needs no UInt192 fallback.

## Probe 3 result

The constructed scale

```text
1 + 2^-24 + 2^-60
```

demonstrates a real double-rounding failure if binary32 is implemented by
calling the exact binary64 kernel and then casting to `float`.

Observed on both baseline compilers:

```text
binary64 intermediate -> exact binary32 midpoint
cast-to-float bits     -> 1065353216
correct once-round bits-> 1065353217
```

Therefore binary32 requires direct one-final-rounding to its own target format.

## Probe 4 — exact binary32 kernel vs independent oracle

A research-only binary32 kernel now implements:

- represented-source float decomposition;
- exact product and quotient construction;
- algebraic cancellation;
- two-limb 128-bit rational arithmetic;
- direct round-to-nearest, ties-to-even binary32 quantization;
- overflow, subnormal, and signed-result construction.

An independent Python `Fraction` oracle generates exact represented float
values, exact rational scales, and expected once-rounded binary32 bit patterns.

The final deterministic set contains boundary cases plus randomized product and
quotient cases with both small and near-63-bit scale components.

Results on each baseline compiler:

```text
R04.17 Probe 4 PASS:
    12007 exact-rational binary32 product/quotient comparisons
    mismatches = 0
```

This validates the single-U128 binary32 architecture before IEEE-special,
CTFE, and performance qualification.


## Probe 5 — IEEE special values

The binary32 dispatcher was exercised over representative +0, -0, finite
subnormal, finite normal, +Inf, -Inf, and NaN values.

For cases where at least one operand is zero, infinity, or NaN, the research
kernel delegates to the native operation before applying any exact finite
kernel.

Both baseline compilers passed:

```text
product special cases:  65
quotient special cases: 65
R04.17 Probe 5 PASS
```

NaN is compared by classification. Infinity and signed zero preserve the native
sign/bit result.

## Probe 6 — CTFE boundary

The binary32 result follows the same path-specific CTFE distinction established
for binary64:

```text
native / identity-rescale float arithmetic
    -> ordinary D semantics
    -> CTFE-capable

nontrivial represented-source binary32 rescale
    -> exact represented float semantics
    -> one final binary32 rounding
    -> runtime-only
    -> deliberate CTFE rejection
```

DMD 2.111 and LDC 1.41 both pass the positive native CTFE probe and reject the
represented-source product/quotient probes with the intentional R04.17
diagnostics.

## Probe 7 — layout-free current real80 decomposition

The current x86-64 baseline reports:

```text
real:
    sizeof   = 16
    mant_dig = 64
    min_exp  = -16381
    max_exp  = 16384
```

A research probe decomposes finite nonzero `real` values without inspecting
their byte layout:

```text
fraction, exponent = frexp(value)
significand        = fraction * 2^real.mant_dig
exponent2          = exponent - real.mant_dig
reconstruct        = ldexp(significand, exponent2)
```

For formats with `real.mant_dig <= 64`, the significand fits a `ulong`.

Fixed boundary values and 20,000 generated full-significand values round-trip
exactly under both baseline compilers:

```text
R04.17 Probe 7 PASS:
layout-free real decomposition round-trips on current <=64-bit significand format
```

This demonstrates feasibility for the current real80 property set without
hard-coding the x87 storage layout.

It is not a portable `real` production decision. D permits other real formats.
In particular, a binary128-like `real` has a 113-bit significand and cannot use
the same `ulong` decomposition carrier.

The structural exact-width implications for the current 64-bit-significand
format are:

```text
product numerator    <= 64 + 64 + 63 = 191 bits
quotient numerator   <= 64 + 63      = 127 bits
quotient denominator <= 64 + 63      = 127 bits
```

Thus a real80-specific exact architecture could reuse a 128-bit quotient path
and a 192-bit product path, but such an implementation remains target/format
research until a deliberate portability policy is chosen.
