# ADR 0002 — Static Relationships Between Dimension, Specification, Unit, and Quantity

- Status: Accepted
- Date: 2026-09-27
- Decision scope: M1 static type relationships

## Context

ADR 0001 selected canonical quantity identity:

```d
Quantity!(Spec, Rep)
```

That decision left the compile-time relationship between Dimension, Spec and
Unit open.

R05 tested the minimal relationship needed by current consumers:

```text
Dimension

Spec
  -> Dimension
  -> CanonicalUnit

Unit
  -> Dimension
  -> ExactScale

Quantity!(Spec, Rep)
  -> stores Rep only
```

The positive probe passed on DMD 2.111 and LDC 1.41. Compile-negative probes
also confirmed that the intended relationship can be enforced on both compiler
baselines:

- a Spec whose CanonicalUnit has the wrong Dimension is rejected;
- a Spec without CanonicalUnit is rejected;
- a Spec without Dimension is rejected.

The probe additionally confirmed that two Specs may share both Dimension and
CanonicalUnit while remaining distinct Quantity identities, and that Unit
diversity does not change `Quantity!(Spec, Rep)` identity.

## Decision

The M1 static type relationship is:

1. Every Spec names exactly one Dimension.
2. Every Spec names exactly one CanonicalUnit.
3. The Spec CanonicalUnit has the same Dimension as the Spec.
4. Every Unit names exactly one Dimension.
5. Every M1 Unit defines an exact rational scale relative to its Dimension's
   reference-unit basis.
6. `Quantity!(Spec, Rep)` identity is determined by Spec and Rep only.
7. Unit identity is used at explicit construction/conversion boundaries and is
   not part of stored Quantity identity.
8. Dimension, Spec and Unit metadata add no per-value runtime storage.

Conceptually:

```text
                +----------------+
                |   Dimension    |
                +----------------+
                   ^          ^
                   |          |
           +-------+--+    +--+-------+
           |   Spec   |    |   Unit   |
           +----------+    +----------+
           | Dimension|    | Dimension|
           | CanonUnit|    | ExactScale
           +-----+----+    +----------+
                 |
                 v
        Quantity!(Spec, Rep)
              stores Rep
```

## Semantic role of each layer

### Dimension

Dimension represents dimensional compatibility, not domain meaning.

Examples:

- Length;
- Time;
- later derived dimensions if promoted.

Dimension equality permits dimensional reasoning but does not imply that two
quantities are semantically interchangeable.

### Specification

Spec represents quantity meaning within a Dimension.

Examples that may share Length Dimension:

- Length;
- Radius;
- Height;
- LinearResolution.

Separate Specs remain separate Quantity types even when they share the same
Dimension and CanonicalUnit.

Reference-system semantics such as ellipsoidal versus gravity-related height,
CRS identity, datum, or raster georeferencing do not automatically belong in
Spec. Those remain domain-layer concerns unless later consumer evidence proves
a reusable generic quantity semantic.

### Unit

Unit represents a named measurement unit within exactly one Dimension.

For the M1 linear slice, Unit supplies an exact rational scale.

Examples:

- metre = 1/1 of the linear reference basis;
- kilometre = 1000/1;
- international foot = 381/1250 metre;
- US survey foot = 1200/3937 metre.

The exact scale participates in conversion algebra, not per-value storage.

### Quantity

Quantity stores only the canonical numeric representation for its Spec.

```d
Quantity!(Spec, Rep)
```

Changing Unit at an input/output boundary does not change Quantity type
identity. Changing Spec or Rep does.

## Normative constraints

1. A Spec is invalid if it lacks Dimension.
2. A Spec is invalid if it lacks CanonicalUnit.
3. A Spec is invalid if CanonicalUnit.Dimension differs from Spec.Dimension.
4. A Unit is invalid if it lacks Dimension.
5. M1 exact linear Units must expose a valid exact rational scale.
6. Two Specs that share Dimension and CanonicalUnit remain distinct semantic
   types.
7. Unit symbols, localized names, parsing aliases and formatting metadata are
   not required for static numerical identity.
8. Runtime CRS/reference-system metadata remains outside this static type
   relationship.
9. `Quantity!(Spec, Rep).sizeof == Rep.sizeof` remains a verified design
   target for representative supported Reps.
10. Construction/conversion APIs must enforce Unit/Spec dimensional
    compatibility at compile time where Unit is statically known.

## Consequences

### Positive

- Dimension compatibility and quantity semantics remain independent.
- Canonical-unit normalization has a single owner: Spec.
- Unit conversion machinery can validate dimensional compatibility without
  participating in stored Quantity type identity.
- Same-dimension semantic types such as Length and Radius remain strongly
  separated.
- Static metadata remains zero-storage.
- The model scales to current geodesy and imagery consumers without embedding
  CRS or reference-system semantics in the generic library.

### Costs

- Spec authors must choose a durable CanonicalUnit.
- Additional semantic Specs increase the concrete Quantity type set even when
  they share Dimension and Unit.
- The library must define a validation mechanism for user-defined Specs and
  Units.
- Derived dimensions and richer Spec relationships require later decisions.

## Alternatives considered

### Unit determines semantic meaning

Rejected. R01/R05 consumer evidence requires an independent Spec axis because
same-dimension quantities can have different meaning.

### Spec without explicit Dimension

Rejected. Deriving dimensional compatibility only indirectly from CanonicalUnit
would collapse semantic structure and make Dimension reasoning less explicit.

### Unit stored in Quantity identity

Rejected by ADR 0001 for the M1 core.

## Not decided by this ADR

This ADR does not select:

- concrete public declaration syntax for Dimension, Spec or Unit;
- traits/concepts used to validate user-defined declarations;
- derived-dimension algebra;
- Spec inheritance/hierarchy or implicit semantic conversions;
- arithmetic result Specs;
- angle treatment;
- display symbols, formatting or localization;
- runtime parsing;
- affine quantity points;
- public conversion function names.

These remain separate M1 or later decisions.

## Evidence

R05 positive probe:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

R05 compile-negative matrix:

- wrong CanonicalUnit Dimension: rejected by DMD and LDC;
- missing CanonicalUnit: rejected by DMD and LDC;
- missing Dimension: rejected by DMD and LDC.

The research probe remains under `research/r05-type-relationships/`.
