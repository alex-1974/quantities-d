# R04.16 — Scalar Division API

**Issue:** #35  
**Status:** Active research  
**Base:** develop@66b850c6314c32ddeeeccc7347065029d5a43599

## Motivation

ADR 0009 deliberately deferred `Quantity / scalar` after R04.15. The
operation is technically simple, but public API surface requires a separate
decision.

No current default-branch workspace consumer directly depends on quantities-d,
so there is no immediate internal call-site requirement.

External prior art supports treating quantity/scalar division as normal scaling:

- Boost.Units exposes quantity divided by scalar and compound scalar division;
- mp-units representation requirements include multiplication and division by
  the underlying scalar for scalable representations.

This is supporting context only; quantities-d keeps its own semantic boundary.

## Candidate contract

Research candidate:

```text
Quantity / scalar
    require isScalableValue!Spec

integral Rep / integral scalar
    unavailable as direct operator
    -> named exactDiv(quantity, scalar) remains authoritative

floating/floating
or safely admitted mixed integral/floating
    -> ResultRep = QuotientArithmeticRep!(Rep, Scalar)
    -> native D division
    -> same Spec
    -> canonical storage unchanged
    -> no unit-rescale kernel

scalar / Quantity
    unavailable
```

The R04.15 complete-domain mixed-representation gate is reused unchanged.

## Probe 1/2 candidate integration

The candidate operator was inserted into the real `Quantity` overload set on
the research branch rather than a proxy type.

Positive compile-time cases include:

- `double Quantity / double -> double Quantity`;
- `float Quantity / double -> double Quantity`;
- `int Quantity / double -> double Quantity`;
- `double Quantity / int -> double Quantity`.

Negative cases include:

- integral Quantity / integral scalar;
- int Quantity / float;
- long Quantity / double;
- scalar / Quantity;
- non-scalable Spec / scalar.

The existing named integral `exactDiv(quantity, scalar)` is retained and
tested in the same overload environment.

## IEEE and CTFE candidate behavior

Because scalar division performs no Unit rescale, admitted floating forms use
ordinary native D division directly.

The research candidate tests at CTFE:

- finite division;
- division by +0 -> +Inf;
- division by -0 -> -Inf;
- 0/0 -> NaN.

No represented-source binary64 kernel or runtime-only CTFE boundary is involved.

## Remaining gates

- DMD 2.111 / LDC 1.41 full repository tests;
- compile-negative gates;
- external consumer;
- optimized codegen comparison;
- overload-resolution confirmation;
- final API-justification decision.


## Qualification results

The final branch-only qualification run passed on both baseline compilers:

```text
DMD 2.111.0
  unit tests            PASS
  compile-negative      PASS
  external consumer     PASS
  release build         PASS
  optimized codegen     PASS

LDC 1.41.0
  unit tests            PASS
  compile-negative      PASS
  external consumer     PASS
  release build         PASS
  optimized codegen     PASS
```

The compile-negative suite confirmed all intended API boundaries:

- raw integral Quantity / integral scalar remains unavailable;
- int Quantity / float is rejected by the complete-domain admission rule;
- long Quantity / double is rejected by the complete-domain admission rule;
- scalar / Quantity remains unavailable;
- non-scalable Specs cannot use scalar division.

The existing named integral `exactDiv(quantity, scalar)` continued to pass its
unit and consumer coverage in the same overload environment.

## Optimized code generation

### LDC 1.41.0

The scalar reference and Quantity operator compile to identical leaf bodies:

```text
raw_scalar_div:
    divsd %xmm1,%xmm0
    ret

quantity_scalar_div:
    divsd %xmm1,%xmm0
    ret
```

### DMD 2.111.0

DMD repeats the same R04.15 native-Quantity code-generation pattern:

```text
raw_scalar_div:
    push
    spill/reload xmm0
    divsd %xmm1,%xmm0
    pop
    ret

quantity_scalar_div:
    push
    spill xmm0
    additional apparently dead movsd -> xmm2
    reload xmm0
    divsd %xmm1,%xmm0
    pop
    ret
```

There are no additional calls or branches. This is the same known DMD 2.111
leaf-code difference already qualified by R04.15, where the corresponding
runtime comparison found no material penalty.

## API justification

There is currently no direct default-branch workspace consumer of quantities-d,
so R04.16 does not claim immediate downstream demand.

However, promotion has more than technical feasibility:

1. scalar multiplication is already part of the scalable-Quantity algebra;
2. `Quantity / scalar` preserves the same Spec and canonical storage, so it
   introduces no new physical semantic resolution;
3. the integral case already has the distinct named `exactDiv` contract,
   producing a clear non-overlapping boundary;
4. external established units libraries treat quantity/scalar division as
   ordinary scaling;
5. the real production overload set was tested directly, including ambiguity,
   negative forms, CTFE, IEEE behavior, consumer compilation, and optimized
   codegen.

The operation is therefore a small completion of the existing scalable-value
contract rather than a new derived-quantity semantic family.

## R04.16 conclusion

The evidence supports promotion of exactly this API:

```text
Quantity!(Spec, Rep) / scalar

requirements:
    isScalableValue!Spec
    QuotientArithmeticRep!(Rep, Scalar) != void

result:
    Quantity!(Spec, ResultRep)

semantics:
    ordinary native floating division
    same Spec
    canonical storage unchanged
    CTFE-capable
    @safe pure nothrow @nogc
```

Explicit non-goals remain:

- integral/integral direct scalar division;
- scalar / Quantity;
- reciprocal Spec synthesis;
- Dimensionless synthesis;
- any represented-source rescale kernel.

R04.16 is ready for selective production promotion plus an ADR 0009 follow-up.
