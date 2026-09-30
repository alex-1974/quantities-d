# R04.17 — D real rescale policy

**Issue:** #37  
**Status:** Qualified research  
**Base:** develop@f3134a5f4b3003582508768ebcf015eb36a0223d

## Decision under research

Nontrivial represented-source `real` canonical rescale is technically and
numerically qualified only for known binary `real` property sets whose
significand fits `ulong`.

Supported format classes:

```text
binary64-like real
    mant_dig = 53
    min_exp  = -1021
    max_exp  = 1024

x87 extended / real80-like
    mant_dig = 64
    min_exp  = -16381
    max_exp  = 16384
```

The gate is based on D-visible numeric traits, not on `real.sizeof`, raw byte
layout, endianness, or ABI-specific x87 decoding.

Other `real` formats, including binary128-like and double-double families,
remain unsupported for nontrivial represented-source rescale.

Identity/native real arithmetic remains ordinary D floating arithmetic.

## Representation and exact widths

For the current real80-like property set, represented finite values have at
most 64 significand bits.

With the current 63-bit positive ExactRatio component range:

```text
product numerator       <= 64 + 64 + 63 = 191 bits
quotient numerator      <= 64 + 63      = 127 bits
quotient denominator    <= 64 + 63      = 127 bits
```

A private UInt192 rational carrier is therefore sufficient for both operations.

The same trait-driven mechanism can instantiate for a 53-bit binary64-like
`real`; Probe 10 validates that form against the independently qualified
binary64 production reference.

## Layout-free represented-source decomposition

Finite nonzero values are decomposed with `frexp` / `ldexp`:

```text
fraction, exponent = frexp(value)
significand        = fraction * 2^mant_dig
exponent2          = exponent - mant_dig
```

For the qualified formats, `mant_dig <= 64`, so the exact represented
significand fits `ulong`.

No storage-layout inspection is required.

## Probe 7 — decomposition

On both baseline compilers, the current real80-like target round-tripped fixed
boundary values plus 20,000 generated full-significand values exactly.

## Probe 9 — current-real exact rational oracle

A trait-driven exact kernel was compared with an independent Python Fraction
oracle.

Results per compiler:

```text
DMD 2.111.0  10,006 comparisons  PASS
LDC 1.41.0   10,006 comparisons  PASS
```

The set includes product, quotient, broad significand/exponent coverage, exact
rational scales, and boundary-oriented vectors.

## Probe 10 — cross-format validation

The same generic kernel instantiated for `double` (`mant_dig=53`) was
compared bit-for-bit with the accepted binary64 production kernel.

Results per compiler:

```text
DMD 2.111.0  40,098 comparisons  PASS
LDC 1.41.0   40,098 comparisons  PASS
```

This demonstrates that the mechanism is driven by binary floating properties
rather than x87 storage layout.

## Quantity integration

A research production candidate added a package capability gate:

```text
supportsExactRealRescale =
    binary64-like real
    OR
    real80-like real
```

Only when this gate is true may a nontrivial positive ProductCanonicalRescale or
QuotientCanonicalRescale select the real exact kernel.

On unsupported targets, the library still builds; the nontrivial real operator
form is simply unavailable.

The candidate passed on both baseline compilers:

- repository unit tests;
- compile-negative tests;
- external consumer;
- release build.

## IEEE and CTFE

Probe 11 compared native and exact-rescale dispatch for +0, -0, finite values,
+Inf, -Inf, and NaN combinations.

Each baseline compiler passed 90 special-value product/quotient comparisons.

Native/identity real arithmetic remains CTFE-capable.

Nontrivial represented-source real rescale is deliberately runtime-only and
rejects CTFE with an intentional diagnostic, matching the binary32/binary64
path-specific contract.

## Probe 12 — Quantity abstraction overhead

Balanced direct-kernel vs Quantity-wrapper medians:

```text
DMD 2.111.0
  product  direct=425741  Quantity=430182  ratio=1.01043
  quotient direct=432233  Quantity=435764  ratio=1.00817

LDC 1.41.0
  product  direct=171948  Quantity=177477  ratio=1.03216
  quotient direct=167368  Quantity=167883  ratio=1.00308
```

No material Quantity abstraction overhead was observed.

## R04.17 real conclusion

The evidence supports selective production promotion with this conditional
contract:

```text
nontrivial Quantity product/quotient canonical rescale
where ResultRep == real:

    available only when real traits match:
        (53, -1021, 1024)
        OR
        (64, -16381, 16384)

    finite nonzero values:
        represented-source exact rational expression
        exact cancellation
        private UInt192 carrier
        one final rounding to the actual real format

    zero / infinity / NaN:
        native real operation

    CTFE:
        identity/native path supported
        nontrivial represented-source path runtime-only
```

Explicitly unsupported:

- binary128-like `real`;
- PowerPC double-double or other non-qualified format families;
- any format requiring a significand wider than 64 bits;
- ABI/layout-dependent decoding.

A future format can be added only after its own width, quantization, oracle,
compiler, integration, and performance evidence.
