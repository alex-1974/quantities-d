# R04.6 — Spec semantics for addition and subtraction

## Goal

Define when Quantity addition and subtraction are semantically valid and which
Spec the result receives.

R04.2 already solves integral representation safety. This research step must
not infer semantic validity from that result machinery.

## Three independent questions

For an operation between `Quantity!(A,...)` and `Quantity!(B,...)` ask:

1. **Dimensional validity** — are the dimensions compatible?
2. **Semantic validity** — does the meaning of A and B permit this operation?
3. **Result Spec derivability** — if valid, which Spec describes the result?

Passing one question does not imply the next.

## Dimension is insufficient

Equal dimensions do not establish semantic interchangeability.

Examples worth preserving as distinct possible Specs include:

- generic Length;
- Distance;
- Height;
- Radius.

All can share a length dimension while representing different domain meanings.

Therefore this must not become the generic rule:

```text
same Dimension => + and - allowed
```

## Same Spec is also not a complete universal rule

For ordinary vector-like/value-like quantities, same-Spec addition and
subtraction are natural candidates:

```text
A + A -> A
A - A -> A
```

But a future affine point/origin model demonstrates why this cannot be an
unconditional property of every Spec:

```text
Point - Point -> Difference
Point + Point -> invalid
Point + Difference -> Point
```

Affine quantities are deferred, but the M3 design should avoid making their
future representation impossible or forcing a breaking semantic correction.

## Candidate models

### Model A — all same-Spec quantities are additive

Rule:

```text
Spec + Spec -> Spec
Spec - Spec -> Spec
```

Advantages:

- minimal API;
- easy operator implementation.

Disadvantages:

- encodes an algebraic promise into every Spec;
- incompatible with affine-like Specs;
- cannot express semantically non-additive domain Specs.

Reject as a universal rule.

### Model B — dimension determines arithmetic

Rule derives validity/result from Dimension.

Reject.

Dimension expresses physical/geometric dimensional compatibility, not the
complete semantic role of a quantity.

### Model C — Spec explicitly declares arithmetic relationships

Conceptually:

```text
AddResult!(LeftSpec, RightSpec)
SubResult!(LeftSpec, RightSpec)
```

A result Spec means the operation is admitted; no result means compile-time
rejection.

Advantages:

- precise;
- can later model affine and cross-Spec relationships;
- keeps representation policy independent.

Risks:

- declaration machinery can become verbose;
- premature generic relationship framework would over-engineer M3.

Keep as architectural direction, but do not yet build a broad relationship
system.

### Model D — minimal value-Spec capability plus future explicit relations

A Spec may opt into closed value arithmetic:

```text
Spec + Spec -> Spec
Spec - Spec -> Spec
```

Cross-Spec and non-closed relationships remain unavailable unless a later
explicit relationship mechanism is justified.

This gives M3 a small production surface without claiming that every Spec is
additive.

Preferred candidate.

## Proposed semantic category: additive value Spec

The important property is semantic, not dimensional:

> An additive value Spec represents a difference/vector-like magnitude for
> which addition and subtraction of two values of the same Spec are closed in
> that Spec.

For such a Spec:

```text
Q!(Spec,A) + Q!(Spec,B) -> Q!(Spec, AddRep!(A,B))
Q!(Spec,A) - Q!(Spec,B) -> Q!(Spec, SubRep!(A,B))
```

subject to the already-proven representation gates.

This property must not be inferred merely because the canonical unit is linear.

## Length question

The current M2 `Length` Spec is the first concrete decision point.

Possible interpretations:

1. `Length` is a generic additive magnitude/difference and may opt into
   closed + and -.
2. `Length` is only a unit-bearing placeholder and should remain neutral
   until more specific semantic Specs exist.

R05 already established that dimension equality does not prove semantic
interchangeability. It did not yet settle the concrete hierarchy among Length,
Distance, Radius, Height and related Specs.

Therefore M3 should make the meaning of `Length` explicit before using it as
the first public arithmetic Spec.

## Cross-Spec arithmetic

Do not admit operations such as:

```text
Distance + Radius
Height - Distance
Length + Height
```

merely because all operands share LengthDimension.

A future explicit relationship can authorize a concrete pair and define its
result Spec.

Default: compile-time rejection.

## Scalar multiplication

Scalar multiplication is different from Quantity + Quantity.

For a value-like quantity:

```text
Q!(Spec,A) * scalar -> Q!(Spec,R)
scalar * Q!(Spec,A) -> Q!(Spec,R)
```

does not combine two semantic Specs and naturally preserves the operand Spec.

This remains a stronger generic candidate than + or -.

Affine point-like Specs would again need to opt out, so scalar closure should
still be a Spec capability rather than inferred from Dimension alone.

## Minimal M3 design direction

Avoid a general algebra DSL.

Prefer a small compile-time trait/capability layer whose semantic source is the
Spec.

Conceptually:

```d
enum isAdditiveValueSpec(Spec) = ...;
```

Then same-Spec + and - are enabled only when that capability is true.

The exact declaration spelling is deliberately not fixed here. Candidate
spellings should be tested for:

- explicitness at the Spec declaration;
- no runtime metadata;
- CTFE;
- @safe pure nothrow @nogc arithmetic;
- useful diagnostics;
- future extension to explicit cross-Spec result relations;
- minimal template/compile-time cost.

## Questions for the next probe

1. Should current `Length` explicitly be an additive value Spec?
2. Should scalar multiplication use the same capability or a separate
   scalable-value capability?
3. What is the smallest declaration mechanism that does not pollute every Spec?
4. Can future `AddResult` / `SubResult` relationships extend it without
   breaking M3 code?
5. Do concrete consumer libraries currently need Distance, Radius or Height
   Specs strongly enough to settle their relationships now?

## Provisional invariants

- Dimension compatibility never grants semantic arithmetic by itself.
- Same Spec never grants arithmetic by itself.
- Cross-Spec arithmetic is rejected by default.
- Public arithmetic requires an explicit semantic relationship/capability plus
  a proven representation policy.
- Result Spec derivation and ResultRep derivation remain independent.
