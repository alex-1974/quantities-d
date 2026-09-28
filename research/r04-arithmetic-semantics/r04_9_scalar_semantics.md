# R04.9 — Scalar arithmetic semantics

## Goal

Define the semantic relationship between a Quantity Spec and dimensionless
scalar arithmetic independently from Rep promotion and loss handling.

## Core distinction

Scalar arithmetic has two layers:

1. **semantic closure** — may this Spec be scaled by a dimensionless scalar?
2. **representation/loss policy** — can the concrete Rep operation represent
   the mathematical result under the selected API?

These must remain independent.

## Proposed semantic capability: scalable value

A scalable value Spec permits multiplication by a dimensionless scalar while
preserving the Spec:

```text
Spec quantity * scalar -> Spec quantity
scalar * Spec quantity -> Spec quantity
```

Conceptually:

```d
enum scalableValue = true;
```

For M3, Length opts in:

```text
Length: scalable value = yes
```

This declaration is independent from `closedAdditiveValue`.

## Why additive and scalable are separate

Neither property should imply the other.

A future semantic type may support differences but not arbitrary scaling, or
may permit scaling while defining different binary quantity relationships.

Therefore do not encode:

```text
closedAdditiveValue => scalableValue
```

and do not use one broad `linearValue` flag merely to save one declaration.

The explicit declarations are cheap and preserve semantic intent.

## Multiplication directions

For a scalable Spec, left and right dimensionless scalar multiplication express
the same semantic operation:

```text
q * s
s * q
```

Both preserve the Quantity Spec.

There is no reason to require separate semantic capabilities for the two
directions.

Representation policy remains operation-specific and must use the proven
integral MulRep or floating promotion rules.

## Division by scalar

Semantically, division by a non-zero dimensionless scalar is also scaling:

```text
q / s = q * (1 / s)
```

and preserves the Spec.

However, semantic closure does not authorize a raw integral `/` operator.

For integral Reps/scalars, R04.2 established that raw D division silently
truncates non-integral quotients. Therefore:

```text
scalableValue == true
```

means division is semantically meaningful, but the concrete public operation
must still obey the representation/loss gate.

This yields:

- floating Quantity / floating scalar: candidate direct operator, subject to
  R04 floating policy;
- integral Quantity / integral scalar: no direct operator;
- integral exact division: named `exactDiv` candidate.

## exactDiv semantic gate

A named integral `exactDiv` should require the same scalable-value semantic
capability as multiplication.

It does not need a separate `exactDivAllowed` Spec marker.

The difference between multiplication and exact division is representational:

- Class-W multiplication can guarantee a result for every operand value;
- exact integral division must classify exact, inexact, or divisionByZero.

Creating separate semantic capabilities for those mechanics would mix the
semantic and representation layers.

## Scalar type scope

M3 scalar arithmetic should initially mean built-in arithmetic scalar Reps
supported by the proven ResultRep/promotion policies.

Do not yet generalize the semantic capability to:

- dimensionless Quantity types;
- arbitrary user numeric types;
- rational wrapper types;
- complex numbers.

Those may later satisfy a broader scalar concept, but are not needed to prove
the M3 slice.

## Negative scalar question

Generic Length is a signed-capable linear magnitude by the R04.7 semantic
decision. Therefore negative scalar scaling is semantically valid for Length.

This does not imply that every future scalable Spec must accept every scalar
domain. A constrained domain type such as a non-negative Radius may require a
different contract or may simply not opt into generic scalableValue.

M3 should not build scalar-domain predicates before a concrete consumer needs
them.

## Proposed Length declaration

Conceptually:

```d
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    enum closedAdditiveValue = true;
    enum scalableValue = true;
}
```

These are semantic declarations only.

Operators should preferably query stable traits rather than repeatedly inspect
members directly:

```text
hasClosedAdditiveValue!Spec
isScalableValue!Spec
```

For binary Quantity arithmetic, AddResult/SubResult remain the richer
result-Spec query layer.

For scalar scaling, the result Spec is necessarily the original Spec in the
M3 capability model, so a separate MulScalarResult trait adds little value
today.

## Future extension

If a future semantic model requires:

```text
SpecA * scalar -> SpecB
```

then a `ScaleResult!(Spec, ScalarCategory)` relationship can be introduced.

Do not build that abstraction before such a case exists.

## M3 decision candidate

For the first Length arithmetic slice:

- `closedAdditiveValue = true`;
- `scalableValue = true`;
- same-Spec + and - use AddResult/SubResult;
- scalar * and * scalar preserve Length;
- exact integral scalar division uses scalableValue plus QuotientRep;
- direct integral scalar / remains unavailable;
- floating scalar / is evaluated separately under R04 floating semantics.

## Invariant

A Spec capability establishes semantic validity only.

It never bypasses ResultRep, overflow, exactness, rounding, or conversion
policy.
