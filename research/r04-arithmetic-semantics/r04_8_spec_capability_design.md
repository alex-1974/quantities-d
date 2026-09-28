# R04.8 — Spec arithmetic capability design

## Goal

Choose the smallest M3 declaration/query model that lets `Length` explicitly
authorize its proven arithmetic without turning quantities-d into a general
algebra DSL.

The design must also leave a clean extension path for future relationships such
as:

```text
Elevation - Elevation -> Length
Point + Difference     -> Point
```

## Requirements

The mechanism should provide:

- explicit semantic authority at or near the Spec declaration;
- no runtime metadata or storage;
- compile-time queryability;
- useful compile-time rejection;
- no inference from Dimension or CanonicalUnit;
- same-Spec Length + and - today;
- future cross-Spec result relationships without breaking today's API;
- compatibility with CTFE and @safe pure nothrow @nogc operations;
- small template/compile-time surface.

## Candidate A — boolean flags on Spec

Example:

```d
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    enum additive = true;
    enum scalable = true;
}
```

### Strengths

- very explicit;
- trivial to inspect;
- minimal machinery.

### Weaknesses

A boolean describes a unary capability, while addition/subtraction are binary
relationships with a result Spec.

It naturally encodes only:

```text
Length op Length -> Length
```

and does not extend naturally to:

```text
A op B -> C
```

Additional flags would eventually become an ad-hoc algebra vocabulary.

Useful as declaration sugar, but weak as the fundamental query model.

## Candidate B — marker types / aliases

Example:

```d
struct AdditiveValue {}
struct ScalableValue {}

struct Length
{
    alias ArithmeticCapabilities =
        AliasSeq!(AdditiveValue, ScalableValue);
}
```

### Strengths

- extensible capability vocabulary;
- compile-time only;
- can be enumerated and validated.

### Weaknesses

- more declaration machinery than M3 needs;
- still models unary capabilities, not binary result relationships;
- requires list membership machinery;
- capability ordering/duplication becomes irrelevant noise.

Defer.

## Candidate C — external specialization registry

Conceptually:

```d
template AddResult(A, B) { alias AddResult = void; }
template AddResult(A : Length, B : Length)
{
    alias AddResult = Length;
}
```

### Strengths

- directly models binary relationships and result Spec;
- naturally extends to cross-Spec operations.

### Weaknesses

- semantic authority can become scattered outside the Spec declaration;
- D template specialization/extension ownership can become awkward across
  modules and packages;
- discoverability is worse;
- third-party specialization policy would need careful control.

Do not use an open external registry as the primary M3 declaration model.

## Candidate D — Spec-local result aliases queried through traits

Conceptually:

```d
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    template AddResult(Rhs)
    {
        static if (is(Rhs == Length))
            alias AddResult = Length;
        else
            alias AddResult = void;
    }

    template SubResult(Rhs)
    {
        static if (is(Rhs == Length))
            alias SubResult = Length;
        else
            alias SubResult = void;
    }
}
```

Library traits provide the stable query surface:

```d
alias AddResult(Lhs, Rhs) = ...;
alias SubResult(Lhs, Rhs) = ...;
```

### Strengths

- the Spec remains the normative semantic authority;
- directly expresses operand relationship and result Spec;
- same-Spec closure is explicit rather than inferred;
- future cross-Spec results fit the same model;
- no runtime state;
- traits can centralize validation and diagnostics.

### Weaknesses

- verbose if every ordinary value Spec repeats the same templates;
- left-owned relation requires a policy for asymmetric declarations;
- careless trait implementation can instantiate malformed declarations.

Best fundamental semantic model among the candidates, but declaration sugar is
desirable for the common closed-value case.

## Candidate E — Spec-local common-case marker plus result traits

Use a minimal marker for the common M3 case:

```d
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    enum closedAdditiveValue = true;
}
```

Stable library queries:

```text
AddResult!(Length, Length) -> Length
SubResult!(Length, Length) -> Length
AddResult!(Length, Other)  -> void
SubResult!(Length, Other)  -> void
```

The trait interprets `closedAdditiveValue` only for exact same-Spec operands.

A future explicit relationship mechanism can be checked before or alongside
the common-case rule without changing operator call sites.

### Strengths

- tiny M3 declaration;
- semantic opt-in remains on the Spec;
- no Dimension inference;
- public/internal arithmetic code depends on result traits, not the marker;
- later binary relations can extend the trait model.

### Weaknesses

- the marker is declaration sugar, not the complete semantic algebra;
- naming must make the same-Spec closure promise clear;
- future relation precedence must be specified when introduced.

Preferred M3 direction.

## Why operators should query result traits

Production operator constraints should not directly inspect:

```d
Spec.closedAdditiveValue
```

They should ask the semantic question:

```text
What is AddResult!(LeftSpec, RightSpec)?
What is SubResult!(LeftSpec, RightSpec)?
```

A non-void result authorizes the operation and supplies its semantic result
Spec.

This separates:

- declaration spelling;
- relationship resolution;
- operator implementation.

It also means the common-case marker can later be replaced or supplemented
without rewriting arithmetic operators.

## Proposed M3 shape

Conceptually:

```d
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    enum closedAdditiveValue = true;
}

template AddResult(Lhs, Rhs)
{
    static if (is(Lhs == Rhs) &&
               hasClosedAdditiveValue!Lhs)
        alias AddResult = Lhs;
    else
        alias AddResult = void;
}

template SubResult(Lhs, Rhs)
{
    static if (is(Lhs == Rhs) &&
               hasClosedAdditiveValue!Lhs)
        alias SubResult = Lhs;
    else
        alias SubResult = void;
}
```

Exact implementation syntax remains subject to a D compile probe.

## Scalar capability

Do not overload `closedAdditiveValue` to mean every scalar operation.

Addition closure and scalar closure are conceptually separate algebraic
properties.

For M3, two options remain:

1. add a separate `scalableValue` marker;
2. explicitly make scalar multiplication part of the meaning of the first
   value capability.

Prefer separation unless the declaration cost proves unjustified.

This avoids future cases where a Spec permits same-Spec differences but not
arbitrary scaling.

## Diagnostics

Operator failure should ideally distinguish:

- no semantic AddResult/SubResult exists;
- semantic relation exists but no safe ResultRep exists.

That mirrors the core architecture:

```text
semantic gate -> representation gate
```

and avoids presenting a signed/width problem as a semantic error.

## Recommended probe

Implement a research-local model with:

- Length: closed additive;
- Radius: no capability;
- dummy Elevation: no same-Spec closure;
- AddResult/SubResult traits;
- Length + Length and Length - Length compile;
- Length + Radius rejects;
- Radius - Radius rejects;
- result trait is independent of Rep;
- a later explicit-result hook can be demonstrated without changing the
  operator-facing query.

Measure/verify on DMD 2.111 and LDC 1.41 before production promotion.

## Provisional decision

Use result traits as the stable semantic query layer.

For M3, let a small Spec-local marker declare the common same-Spec closed
additive case. Do not expose a general capability list or open specialization
registry.

Metaprogramming should remove repetitive declarations while leaving the
semantic relationship visible.
