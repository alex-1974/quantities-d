# R04.7 — Length and semantic length Specs

## Goal

Fix the semantic role of the existing M2 `Length` Spec and avoid using it as
an implicit umbrella relationship for every quantity with LengthDimension.

## Decision: Length is a generic linear magnitude

The existing `Length` Spec represents a generic linear length magnitude.

It is not:

- a base class for all length-related semantic Specs;
- an implicit conversion target for every Spec with LengthDimension;
- proof that two semantic length Specs are interchangeable.

Its closed value arithmetic is meaningful:

```text
Length + Length -> Length
Length - Length -> Length
Length * scalar -> Length
scalar * Length -> Length
```

Integral scalar division remains subject to the explicit exact-division policy
from R04.2.

This makes `Length` the first concrete additive/scalable value Spec for M3.

## Dimension and unit reuse

Future semantic Specs may reuse:

- `LengthDimension`;
- `Metre` as CanonicalUnit;
- the same public linear units.

For example, conceptually:

```d
struct Distance
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct Height
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct Radius
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}
```

This shared representation infrastructure does not create arithmetic
relationships among the Specs.

## Distance

Distance normally describes a separation or path-length-like magnitude.

Potential same-Spec closure:

```text
Distance + Distance -> Distance
Distance - Distance -> Distance
Distance * scalar -> Distance
```

This can be useful, but it is not required to settle M3 Length arithmetic.

Do not add Distance merely as a synonym for Length.

A concrete consumer should justify the distinction and its exact algebra.

## Height

Height is more context-sensitive.

A height may mean:

- a vertical extent/difference;
- an elevation relative to a datum/origin.

Those have different subtraction semantics. In the second interpretation it
starts to resemble an affine point quantity:

```text
Elevation - Elevation -> vertical difference
```

rather than necessarily:

```text
Height - Height -> Height
```

Therefore do not declare a generic Height Spec additive until its semantic role
is explicit.

This is direct evidence that same Dimension and same Spec cannot universally
authorize subtraction.

## Radius

Radius is a non-negative geometric/domain concept in many APIs, but the current
Quantity Rep model does not itself enforce non-negativity.

Operations such as:

```text
Radius + Radius
Radius - Radius
```

are mathematically computable but their semantic result is not automatically a
Radius. Subtraction can be negative; addition may be better understood as a
generic Length depending on the domain.

Therefore Radius should not automatically opt into same-Spec additive closure.

Scalar scaling may be meaningful, but negative scalar multiplication again
raises domain-validity questions if Radius promises non-negativity.

Do not define Radius algebra before deciding whether domain constraints belong
in the Spec/type contract.

## Why Length should remain permissive

Generic `Length` does not promise a domain role such as radius, elevation or
distance-from-origin. It is therefore the appropriate place for ordinary
linear magnitude algebra.

A negative result of:

```text
Length(2 m) - Length(5 m)
```

is a valid generic length difference in this algebra.

This is a semantic choice: `Length` means a signed-capable linear magnitude,
not necessarily a physical object's non-negative measured extent.

Whether a concrete Rep is signed or unsigned remains a separate representation
choice.

## Cross-Spec policy

No implicit arithmetic or conversion relationship follows from sharing
LengthDimension.

Default examples:

```text
Length + Distance    -> reject
Distance + Radius    -> reject
Height - Length      -> reject
Radius - Radius      -> reject unless Radius later declares a result relation
```

Future explicit relations may deliberately produce a different result Spec.

For example, a future model could choose:

```text
Elevation - Elevation -> Length
```

without changing the generic Length rules.

## M3 consequence

The first production arithmetic slice can target only `Length`.

This is sufficient to exercise:

- additive Spec capability;
- same-Spec + and -;
- scalar multiplication;
- integral ResultRep machinery;
- floating Rep promotion;
- explicit integral exact division.

There is no need to introduce Distance, Height or Radius merely to prove the
framework.

## Capability implication

R04.6 proposed an additive-value capability. This decision provides the first
positive case:

```text
Length: additive value = yes
```

It also shows why a single broad `isLinearDimension` or
`isLengthDimension` trait is insufficient.

The next research step should compare minimal ways for a Spec such as Length to
declare its arithmetic capabilities without introducing a general algebra DSL.

## Invariants

- `Length` is a generic linear magnitude.
- `Length` is closed under same-Spec addition and subtraction.
- `Length` is closed under semantically valid scalar scaling.
- shared Dimension and CanonicalUnit do not imply Spec interchangeability.
- Distance, Height and Radius remain deferred until concrete consumer semantics
  justify them.
- no semantic hierarchy is inferred from names.
