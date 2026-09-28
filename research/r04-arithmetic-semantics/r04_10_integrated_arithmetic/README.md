# R04.10 — Integrated Quantity arithmetic gate

## Goal

Integrate the previously isolated R04 decisions in one research-local
Quantity-shaped model before modifying production code.

The gate composes:

```text
Spec semantics
    -> ResultSpec
    -> ResultRep
    -> Quantity operation
```

Semantic authorization and representation safety must both succeed.

## Scope

Positive M3 Length slice:

- same-Spec addition;
- same-Spec subtraction;
- Quantity * integral scalar;
- integral scalar * Quantity;
- named exact integral scalar division.

Negative gates:

- same-Dimension non-additive Spec arithmetic;
- cross-Spec arithmetic;
- Class-O integral Rep combinations;
- raw integral Quantity / scalar.

## Semantic model

Length declares:

- closedAdditiveValue;
- scalableValue.

Radius shares LengthDimension and Metre but declares neither.

Addition/subtraction use AddResult/SubResult.

Scalar multiplication and exact division use scalableValue.

## Representation model

Use the already researched type-only traits:

- AddRep;
- SubRep;
- MulRep;
- QuotientRep.

A void result rejects the operation at compile time.

## exactDiv

The integrated prototype keeps only the reachable Class-W states:

- exact;
- inexact;
- divisionByZero.

No overflow state is needed because non-void QuotientRep proves every exact
quotient representable.

## Required gates

- int + uint Length -> long Length;
- uint - uint Length -> long Length, including negative result;
- uint * uint scalar -> ulong Length;
- symmetric scalar multiplication;
- int.min / -1 -> exact long Length;
- 5 / 2 -> inexact, no payload;
- division by zero -> divisionByZero, no payload;
- CTFE;
- @safe pure nothrow @nogc;
- Radius + Radius rejects;
- Length + Radius rejects;
- tested Class-O operations reject;
- raw integral / rejects.

Passing this gate does not itself promote the API. It establishes that the
researched semantic and representation layers compose coherently.
