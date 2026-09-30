# ADR 0009 — Binary64 Floating Arithmetic Semantics

- Status: Accepted
- Date: 2026-09-30
- Research: R04.15 — floating arithmetic
- Issue: #27
- Related: ADR 0001, ADR 0004, ADR 0006, ADR 0007, ADR 0008

## Context

The accepted quantities-d core stores a Quantity as `Quantity!(Spec, Rep)`
with canonical-unit storage. Integral arithmetic already separates semantic
validity, physical Dimension, exact Unit rescaling, and representation safety.

Floating arithmetic remained research-first because ordinary IEEE-754
arithmetic, mixed representation promotion, exact rational canonical rescaling,
CTFE, and compiler code generation impose different constraints from the
integral Class-W/O64/OM model.

R04.15 evaluated same-Spec addition/subtraction, scalar arithmetic,
Quantity-by-Quantity product/quotient semantics, mixed integral/floating
representation admission, nontrivial canonical rescaling, IEEE special values,
fixed-width exact kernels, runtime performance, and the CTFE boundary on the
baseline DMD 2.111 and LDC 1.41 toolchains.

This ADR promotes only the evidence-backed binary64 arithmetic contract and the
representation rules needed to compose it with the existing semantic machinery.
It does not generalize the nontrivial exact-rescale kernel to `float` or
`real`.

## Decision

### 1. Floating arithmetic does not inherit the integral range classes

ADR 0008 Class W/O64/OM is an integral representation-availability model.

Floating arithmetic instead follows ordinary floating value semantics after an
operation has passed the existing semantic and representation-admission gates.
Finite overflow may produce infinity and ordinary floating rounding is part of
the direct operation contract.

A floating direct operator therefore does not imply the integral Class-W
guarantee that every mathematical result is representable without range loss.

### 2. Semantic validity remains independent from representation policy

Existing semantic machinery remains authoritative.

Examples include:

- `AddResult` / `SubResult` for additive compatibility;
- `isScalableValue` for scalar operations;
- `ProductResultSpec` / `ExternalProductResultSpec`;
- `QuotientResultSpec` / `ExternalQuotientResultSpec`;
- physical Dimension validation;
- exact canonical Unit rescale derivation.

Floating support must not make a semantically invalid operation valid merely
because D can evaluate the underlying scalar expression.

### 3. ResultRep selection extends beside, not through, the integral selectors

The existing integral `AddRep`, `SubRep`, `MulRep`, and related range
selectors retain their current contracts.

A floating representation dispatcher may layer additional cases beside them.

For floating/floating operands, the ResultRep follows native D floating
promotion for the validated combinations.

For mixed integral/floating operands, a direct operation is admitted only when
the complete integral operand Rep domain is exactly representable in the
floating ResultRep.

The evidence-backed criterion is:

```d
valueBits!Integral <= Floating.mant_dig
```

where signed integral `valueBits` excludes the sign bit and unsigned
`valueBits` includes the complete width.

This gate concerns exact operand conversion only. It does not promise that the
final floating arithmetic result is mathematically exact.

`bool` is excluded from this arithmetic admission policy.

### 4. Same-Spec floating addition and subtraction use native arithmetic

When semantic validity and ResultRep admission succeed, same-Spec floating
addition/subtraction operate directly on canonical stored values using native D
floating arithmetic.

Canonical storage means no Unit rescale is required for these operations.

Ordinary floating result rounding and IEEE behavior are inherited from the
admitted floating ResultRep.

### 5. Identity-rescale floating product and quotient use native arithmetic

When an explicit semantic product or quotient relation resolves a valid
ResultSpec and the exact canonical rescale is `1/1`, floating
Quantity-by-Quantity multiplication/division may use the corresponding native D
operation in the admitted floating ResultRep.

Dimensionless mathematical results do not invent a generic semantic
Dimensionless Spec. The existing explicit semantic relation requirement
remains unchanged.

### 6. Nontrivial binary64 canonical rescale uses one exact joint rational evaluation

For `double` product or quotient with a nontrivial exact canonical rescale,
quantities-d does not use a fixed sequential floating evaluation order.

R04.15 demonstrated that all of the following can disagree with the exact
mathematical expression rounded once to binary64:

- product/quotient first, then rescale;
- rescale the left/numerator operand first;
- rescale the right/denominator operand first.

The disagreement includes avoidable overflow/underflow and ordinary one-ULP
multiple-rounding differences.

The binary64 semantic model is therefore:

1. interpret each finite input from its represented binary64 value;
2. combine both represented operands and the exact canonical scale as one exact
   rational expression;
3. cross-cancel exact factors before widening;
4. round exactly once to binary64 using round-to-nearest, ties-to-even.

The exact rational scale remains part of type semantics and is not converted to
an approximate floating scale before evaluation.

### 7. Quotient and product use different internal widths

The current exact structural bounds are:

```text
quotient:
    numerator   <= 116 bits
    denominator <= 116 bits

product:
    numerator   <= 169 bits
    denominator <= 63 bits
```

The binary exponent is tracked separately.

The portable binary64 quotient kernel therefore retains a narrow
`Cent/Cent` representation.

The binary64 product kernel uses a two-tier internal representation:

```text
exact decomposition + cross-cancellation
        |
        +-- safely <=127 numerator bits
        |       -> Cent product + Cent quantizer
        |
        +-- otherwise
                -> UInt192 product + UInt192 quantizer
```

The `<=127` cutoff is deliberately conservative. It leaves headroom for the
current narrow quantizer and avoids adding more complex 128-bit classification
without demonstrated benefit.

The internal `UInt192` representation is an implementation detail, not a
public Quantity Rep and not a general wider-integer API.

### 8. Source symmetry is subordinate to measured performance

A single always-wide UInt192 quantizer is not the default portable
architecture.

R04.15 measured the narrow quotient kernel against a losslessly widened
UInt192 form. The UInt192 quotient path was approximately 82% slower at the
median on DMD 2.111 and approximately 2% slower on LDC 1.41.

For products, the conservative Cent fast path plus UInt192 fallback was
approximately 57% faster at the median than always-wide UInt192 on DMD 2.111
and approximately 1.5% faster on LDC 1.41 in the deterministic research
workload.

The two-tier product architecture is therefore justified across the supported
baseline compiler matrix without introducing compiler-specific public
semantics.

### 9. IEEE special values retain ordinary native behavior

For direct binary64 arithmetic involving NaN, infinity, or signed zero,
quantities-d preserves ordinary IEEE-754 special-value behavior.

For product/quotient with a positive finite canonical rescale:

```text
at least one operand is ±0 / ±Inf / NaN
    -> native IEEE product/quotient special-value behavior

finite nonzero operands
    -> exact represented-source rational kernel
```

NaN payload bits and NaN sign are not part of the quantities-d contract.

Signed zero and infinity sign are preserved according to the native operation.

Ordinary direct floating arithmetic does not introduce a checked/status result
carrier merely because NaN or infinity can occur.

### 10. CTFE capability is path-specific

Native and identity-rescale floating arithmetic remains usable in ordinary D
CTFE and retains `@safe pure nothrow @nogc` where the underlying operation
does.

However, D CTFE may retain excess floating precision beyond the nominal
binary32/binary64 storage boundary. CTFE evaluation is therefore not a
bit-exact oracle for materialized floating storage.

For nontrivial binary64 product/quotient canonical rescale, represented-source
binary64 semantics are part of the operation contract. Arbitrary-`double`
CTFE must not silently substitute excess-precision D evaluation for that
runtime contract.

Such represented-source rescale paths are therefore runtime-only for arbitrary
`double` operands and must reject CTFE deliberately before bit decomposition
with an intentional quantities-d diagnostic.

This is consistent with ADR 0007.

### 11. Direct floating arithmetic does not reuse conversion status semantics

`ConversionStatus`, exact conversion, and checked conversion describe explicit
representation/unit conversion intent.

Ordinary admitted floating arithmetic instead returns a Quantity directly and
uses ordinary floating semantics, including rounding, infinity, signed zero,
and NaN.

The exact rational kernel for nontrivial binary64 canonical rescale exists to
define the arithmetic result correctly. It does not turn ordinary direct
floating arithmetic into an exact/checked result-carrier API.

## Scope of the first production slice

The first production promotion from this ADR may include:

- floating same-Spec addition/subtraction through the representation dispatcher;
- evidence-backed mixed integral/floating admission;
- floating scalar multiplication where the existing scalable-Spec contract
  admits the operation;
- floating Quantity-by-Quantity product where an existing semantic relation
  resolves the ResultSpec;
- floating Quantity-by-Quantity quotient only where the existing quotient
  semantic relation model explicitly resolves the ResultSpec;
- native identity-rescale paths;
- nontrivial represented-source exact rescale for `double` only.

Scalar division was deliberately left for a separate API-surface decision in
R04.15.

R04.16 subsequently qualified and promoted `Quantity / scalar` for scalable
Specs under the existing floating representation-admission policy.

The accepted follow-up contract is:

- `Quantity / scalar` only;
- `isScalableValue!Spec` remains the semantic gate;
- floating/floating and safely admitted mixed integral/floating forms use
  `QuotientArithmeticRep!(Rep, Scalar)`;
- the result preserves the same Spec and canonical storage;
- ordinary native floating division supplies IEEE and CTFE semantics;
- integral/integral direct scalar division remains unavailable and continues to
  use the named `exactDiv(quantity, scalar)` API;
- `scalar / Quantity` remains unavailable because it changes physical
  semantics and would require an explicit reciprocal ResultSpec.

R04.16 passed unit, compile-negative, external-consumer, release-build, and
optimized-code-generation qualification on DMD 2.111.0 and LDC 1.41.0. LDC
emitted an instruction-identical `divsd` leaf relative to the scalar
reference. DMD repeated the already-qualified R04.15 pattern of the same
floating operation plus one additional apparently dead `movsd` load.

## Explicitly deferred

This ADR does not promote:

- a nontrivial exact-rescale kernel for `float`;
- a nontrivial exact-rescale kernel for `real`;
- portable assumptions about the representation of D `real`;
- mixed integral/floating operations whose complete integral operand domain is
  not exactly representable by the selected floating ResultRep;
- automatic cross-Spec arithmetic merely from matching Dimensions;
- an automatic semantic Dimensionless result Spec;
- a public exact-source floating CTFE representation;
- generic floating mathematical functions such as `sqrt`, `hypot`, or
  trigonometric functions;
- a general public UInt192/wider-integer representation.

## Alternatives considered

### Use native sequential floating operations for nontrivial rescale

Rejected because evaluation order can create avoidable overflow/underflow and
frequent one-ULP disagreement with the exact once-rounded result.

### Always rescale one operand first

Rejected because neither left-first nor right-first is generally correct across
the tested range.

### Restrict all floating product/quotient to identity rescale

Not selected for binary64 because the exact joint kernel is feasible,
fixed-width, validated against an independent exact oracle, and has an
evidence-backed portable architecture.

### Use one shared UInt192 quantizer for product and quotient

Rejected as the portable default because DMD 2.111 shows a large measured
runtime penalty for the unnecessarily widened quotient path.

### Make all floating arithmetic runtime-only

Rejected because native and identity-rescale operations remain valid ordinary D
CTFE operations. Only the represented-source nontrivial binary64 rescale
requires an explicit runtime boundary.

### Treat NaN/infinity as arithmetic failures

Rejected because ordinary direct floating arithmetic should preserve native
IEEE behavior. Conversion APIs retain their distinct `nonFinite` status
because conversion intent is a different contract.

### Generalize immediately to float and real

Rejected. The exact nontrivial-rescale kernel and fixed-width bounds were
validated for represented binary64. `real` is target-dependent and binary32
requires its own validated width/rounding contract.

## Consequences

- Floating arithmetic composes with the existing semantic Spec/Dimension/Unit
  architecture rather than bypassing it.
- Integral range-safety contracts remain unchanged.
- Same-Spec add/sub and identity-rescale product/quotient can remain simple
  native operations.
- Nontrivial binary64 product/quotient gains deterministic exact-once-rounding
  semantics independent of arbitrary evaluation ordering.
- The portable implementation carries two internal fixed-width product paths,
  but no wider public integer representation.
- DMD receives a substantial runtime benefit from the narrow product fast path;
  LDC is not materially penalized.
- Arbitrary-double CTFE remains available where ordinary D semantics are the
  contract and is deliberately rejected where represented-source binary64 is
  the contract.
- Future float/real support can extend the representation layer without
  redefining the binary64 decision.

## Validation evidence

R04.15 evidence includes:

- native D floating result-type and IEEE baseline probes;
- CTFE excess-precision/materialization probes;
- mixed integral/floating operand-domain admission checks;
- integration with the actual Quantity semantic gates;
- external positive and compile-negative consumers;
- identity-rescale Quantity product/quotient integration;
- evaluation-order counterexamples;
- an independent Python Fraction exact oracle;
- structural fixed-width proofs;
- 100,000-case Cent/Cent exact rational validation;
- complete binary64 quotient quantization against the oracle;
- complete binary64 product quantization using a minimal UInt192 numerator;
- runtime architecture benchmarks on DMD 2.111 and LDC 1.41;
- 630 IEEE-special product cases and 630 quotient cases per baseline compiler;
- positive native/identity CTFE tests;
- deliberate negative CTFE tests for represented-source nontrivial rescale.

Final R04.15 qualification completed these promotion gates on the baseline
toolchains.

Optimized native/identity code generation was compared directly with equivalent
scalar leaf functions:

- LDC 1.41.0 emitted instruction-identical bodies for addition, subtraction,
  scalar multiplication, identity product, and identity quotient;
- DMD 2.111.0 emitted the same floating arithmetic and control flow but retained
  one additional apparently dead `movsd` load in each Quantity leaf;
- a balanced DMD runtime comparison measured a Quantity/scalar median ratio of
  `1.00005`, providing no evidence of a material runtime penalty from that
  code-generation difference.

Representative compile-time impact was also measured against the same
`import quantities` baseline:

- DMD 2.111.0: `77.811 ms -> 82.516 ms`, ratio `1.060`;
- LDC 1.41.0: `316.528 ms -> 328.961 ms`, ratio `1.039`.

The production slices passed the repository unit, compile-negative,
external-consumer, and release-build gates on DMD 2.111.0 and LDC 1.41.0.

R04.15 therefore satisfies the required qualification for this ADR. Scalar
division and nontrivial `float`/`real` rescaling remain explicit deferred
scope rather than conditions of this accepted binary64 contract.
