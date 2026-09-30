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
