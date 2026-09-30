# ADR 0010: Exact nontrivial binary32 canonical rescale

- Status: Accepted
- Date: 2026-09-30
- Issue: #37
- Related: ADR 0009

## Context

ADR 0009 established represented-source exact-once-rounding semantics for
nontrivial binary64 Quantity product/quotient canonical rescale.

It explicitly deferred `float` because a direct binary32 contract had not yet
been validated.

R04.17 investigated binary32 separately rather than routing represented
`float` operands through the binary64 kernel.

The distinction matters because one correctly rounded binary64 intermediate
followed by a cast to binary32 can double-round.

R04.17 constructed the exact scale

```text
1 + 2^-24 + 2^-60
```

for represented `1.0f * 1.0f`.

The exact value is just above a binary32 midpoint and must round upward when
rounded once directly to binary32. Correct binary64 rounding first loses the
`2^-60` term, lands exactly on the binary32 midpoint, and the subsequent
binary32 tie-to-even cast rounds downward.

Therefore binary32 requires its own final quantizer.

## Decision

### 1. Binary32 follows the represented-source exact-rescale model

For nontrivial positive canonical rescale where the admitted ResultRep is
`float`, Quantity product/quotient semantics are:

1. interpret finite operands from their represented IEEE binary32 values;
2. combine both represented operands and the exact rational canonical scale as
   one exact rational expression;
3. cross-cancel exact integer factors before widening;
4. round exactly once to binary32 using round-to-nearest, ties-to-even.

The exact scale is never approximated as a floating value before the final
rounding step.

Identity-rescale paths remain ordinary native D floating arithmetic.

### 2. Binary32 uses a two-limb 128-bit exact carrier

A finite represented binary32 operand has at most 24 significand bits.

With the current positive signed-64-bit ExactRatio component range, the
pre-cancellation structural maxima are:

```text
product numerator       <= 111 bits
quotient numerator      <= 87 bits
quotient denominator    <= 87 bits
```

Cross-cancellation can only reduce those bounds.

Both product and quotient therefore use one private two-limb 128-bit exact
representation. Binary32 does not require the UInt192 product fallback used by
binary64.

No wider integer carrier becomes public API.

### 3. IEEE special values preserve native behavior

If zero, infinity, or NaN participates, the binary32 rescale dispatcher uses
the corresponding native product/quotient operation.

This preserves ordinary D/IEEE behavior for:

- NaN classification;
- infinity;
- signed zero;
- invalid combinations such as infinity times zero.

NaN payload/sign is not part of the quantities-d contract.

### 4. Nontrivial represented-source binary32 rescale is runtime-only

Native and identity-rescale `float` arithmetic remains ordinary D CTFE.

Nontrivial represented-source binary32 rescale deliberately rejects CTFE before
bit decomposition, matching the path-specific boundary established by ADR 0009.

This prevents D compile-time excess precision from silently replacing the
represented-source runtime contract.

### 5. Quantity semantic gates remain unchanged

Binary32 support does not make a semantically invalid operation valid.

Product/quotient still require:

- explicit semantic result resolution;
- physical Dimension validation;
- exact canonical rescale derivation;
- admitted floating ResultRep.

Mixed integral/floating admission remains governed by the existing complete
integral-domain exact-representability rule.

### 6. D `real` is not included

This ADR makes no portable nontrivial-rescale promise for `real`.

R04.17 confirmed that the current x86-64 baseline has a 64-bit-significand
real80 property set and that represented values can be decomposed/reconstructed
without byte-layout assumptions via `frexp`/`ldexp`.

That is feasibility evidence for this format class, not a portable D contract.
Other supported targets may expose binary64-like, binary128-like, or other
`real` representations requiring different exact widths and quantizers.

The `real` policy remains research.

## Validation evidence

R04.17 binary32 qualification includes:

- DMD 2.111.0 and LDC 1.41.0 format/property probes;
- structural exact-width derivation;
- a concrete binary64-to-binary32 double-rounding counterexample;
- an independent Python Fraction oracle;
- 12,007 exact product/quotient comparisons per baseline compiler with zero
  mismatches;
- 65 product and 65 quotient IEEE-special cases per compiler;
- native CTFE positive tests and deliberate represented-source CTFE negative
  diagnostics;
- integration through the actual Quantity semantic/result/rescale machinery;
- repository unit and compile-negative gates;
- external-consumer coverage;
- release builds;
- optimized performance/code-generation qualification.

Equivalent-semantics Quantity/direct-kernel runtime medians showed no material
Quantity abstraction overhead:

```text
DMD 2.111.0
  product  0.998912
  quotient 0.997503

LDC 1.41.0
  product  1.00019
  quotient 0.998551
```

Naive sequential float arithmetic is substantially cheaper in the measured DMD
workload, but it is not an interchangeable implementation because the
double-rounding/evaluation-order research demonstrates different numerical
results.

## Acceptance

The qualified binary32 production slice was merged via PR #38 and remains green under the repository baseline CI. R04.17 subsequently completed the separate D `real` policy without changing this binary32 contract.

## Consequences

- nontrivial `float` canonical rescale gains deterministic represented-source
  one-final-rounding semantics;
- binary32 product/quotient share one small private exact carrier;
- the accepted binary64 implementation remains unchanged;
- identity/native floating fast paths remain unchanged;
- no public wide-integer API is added;
- `real` remains explicitly format-dependent research.
