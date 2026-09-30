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
