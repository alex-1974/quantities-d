# ADR 0011: Conditional exact nontrivial D real canonical rescale

- Status: Proposed
- Date: 2026-09-30
- Issue: #37
- Related: ADR 0009, ADR 0010

## Context

D `real` is implementation-defined. The language and Phobos permit multiple
format families, so a single nontrivial represented-source rescale
implementation cannot be assumed valid merely because the operand type is
`real`.

R04.17 therefore treated `real` as a format-policy problem rather than as a
larger `double`.

The research established two qualified binary format property sets:

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

The accepted mechanism is driven only by D-visible numeric traits. It does not
inspect `real.sizeof`, raw bytes, endianness, x87 register layout, or ABI
padding.

## Decision

### 1. Nontrivial real rescale is conditionally available

The library defines an internal capability gate equivalent to:

```text
supportsExactRealRescale =
    real traits match binary64-like
    OR
    real traits match real80-like
```

When the gate is false, quantities-d still compiles normally, but nontrivial
ProductCanonicalRescale / QuotientCanonicalRescale with ResultRep `real` is
not a valid direct operator form.

Identity-rescale `real` arithmetic remains ordinary native D arithmetic on all
targets.

### 2. Qualified real formats use represented-source exact semantics

For finite nonzero operands and positive nontrivial canonical scale:

1. decompose each represented `real` value with `frexp` / `ldexp`;
2. reconstruct its exact integer significand and base-2 exponent from
   `real.mant_dig`;
3. combine both represented operands and the exact rational scale into one
   exact rational expression;
4. cross-cancel exact integer factors before widening;
5. round exactly once to the actual `real` format using the format's
   `mant_dig`, `min_exp`, and `max_exp`.

The implementation does not approximate the scale as floating point before the
final rounding.

### 3. A private UInt192 carrier is sufficient for the qualified formats

For the wider qualified format, `mant_dig == 64`.

With the current positive 63-bit ExactRatio component range:

```text
product numerator       <= 191 bits
quotient numerator      <= 127 bits
quotient denominator    <= 127 bits
```

A private UInt192 rational carrier therefore covers both product and quotient.

No wide integer representation becomes public API.

### 4. IEEE special values preserve native behavior

If zero, infinity, or NaN participates, the real rescale dispatcher uses the
corresponding native product or quotient.

NaN payload/sign is not part of the quantities-d contract. Classification,
infinity sign, and signed zero follow the native operation.

### 5. CTFE remains path-specific

Native and identity-rescale real arithmetic remains ordinary D CTFE.

Nontrivial represented-source real rescale is deliberately runtime-only and
rejects CTFE before represented-source decomposition.

This matches ADR 0009 and ADR 0010.

### 6. Unsupported real formats are not approximated or silently narrowed

The current contract does not support:

- binary128-like `real` with a 113-bit significand;
- PowerPC double-double;
- other implementation-defined real formats not matching the two qualified
  trait sets.

Such targets do not fall back through `double`, do not reinterpret storage,
and do not use a weaker sequential floating expression.

Support for another format requires its own exact-width, rounding, oracle,
compiler, integration, and performance evidence.

## Validation evidence

R04.17 includes the following evidence on DMD 2.111.0 and LDC 1.41.0.

### Layout-free decomposition

Fixed boundary values plus 20,000 generated current-real values round-trip
through `frexp` / exact integer significand / `ldexp` reconstruction.

### Independent real80-like exact-rational oracle

Each compiler passed:

```text
10,006 product/quotient comparisons
mismatches = 0
```

### Cross-format binary64 validation

The same trait-driven exact mechanism instantiated for a 53-bit binary64
format and matched the already accepted binary64 production kernel:

```text
40,098 comparisons per compiler
mismatches = 0
```

### Repository integration

The research production candidate passed on both baseline compilers:

- unit tests;
- compile-negative tests;
- external consumer;
- release build.

### IEEE special values

Each compiler passed 90 native-vs-dispatch special-value comparisons.

### Quantity abstraction overhead

Equivalent-semantics direct-kernel vs Quantity-wrapper medians:

```text
DMD 2.111.0
  product  ratio 1.01043
  quotient ratio 1.00817

LDC 1.41.0
  product  ratio 1.03216
  quotient ratio 1.00308
```

No material Quantity-layer overhead was observed.

## Consequences

- qualified binary64-like and real80-like D `real` formats gain the same
  represented-source one-final-rounding contract as binary32/binary64;
- unsupported real formats remain compile-time unavailable for nontrivial
  direct rescale while the rest of the library stays usable;
- no platform name, ABI layout, or endianness becomes part of the contract;
- adding another `real` format is an explicit future qualification task.
