# quantities-d Research

## Purpose

This document is the library-local evidence backlog. Research entries are not
features and do not become public API without explicit promotion into an ADR,
roadmap commitment, implementation contract, tests, and where relevant
benchmarks.

## R01 — Static representation model

### Question

Which representation gives D the best combination of semantic strength,
ergonomics, compile-time cost, code generation, and consumer compatibility?

### Candidates

```text
A  Quantity!(Unit, Rep)
B  Quantity!(Spec, Unit, Rep)
C  Quantity!(Spec, Rep) with canonical storage
```

### Evidence required

- DMD 2.111 and LDC 1.41 compile probes;
- `sizeof` and layout checks;
- optimized code-generation comparison;
- CTFE and attribute inference/compatibility;
- compile-negative contract tests;
- representative geodesy, geometry, and raster-adjacent call sites.

### Promoted decision

R01 is promoted by `docs/adr/0001-canonical-quantity-identity.md`.

M1 selects `Quantity!(Spec, Rep)` with canonical storage. `Spec` remains a
first-class semantic axis and defines the canonical Unit contract. Source Unit
is explicit compile-time metadata at construction/conversion boundaries rather
than part of stored Quantity type identity.

Candidate B remains a documented alternative in the research record; its
persistent source-Unit identity did not justify the measured type-instantiation
scaling cost for current consumers.

## R02 — Unit representation and exact conversion

### Current findings

- unit identity must be compile-time metadata in the static core;
- unit metadata must not be stored as an empty per-value struct field;
- exact definitions such as international foot and US survey foot should retain
  rational definitions rather than immediately collapsing to approximate
  floating constants;
- no unit may be inferred from scalar magnitude.

### Questions

- minimal compile-time rational representation;
- overflow-safe ratio composition;
- conversion promotion rules;
- integer and floating representation policy.

## R03 — Conversion and loss policy

### Current recommendation

Potentially lossy conversion must not happen silently.

Research:

- when conversion may be implicit because it is value-preserving;
- explicit `to`/`in` API shape;
- integer division and rounding policy;
- floating narrowing policy;
- overflow/underflow behavior;
- checked versus unchecked conversion, if both are justified.

## R04 — Arithmetic semantics

Research:

- same-unit and mixed-unit addition/subtraction;
- multiplication/division and derived dimensions;
- dimensionless results;
- comparisons;
- scalar multiplication;
- `sqrt`, `abs`, `hypot` and other operations demanded by consumers;
- prevention of nonsensical operations at compile time.

## R05 — Quantity specification / kind semantics

### Motivation

Dimension equality alone does not prove semantic interchangeability. Distance,
radius, width, and height may all have length dimension while representing
different domain concepts.

### Promoted type-relationship decision

R05 is promoted by `docs/adr/0002-static-type-relationships.md`.

The M1 relationship is now fixed at the architectural level: Spec names
Dimension and CanonicalUnit; Unit names Dimension and exact rational scale;
Quantity identity remains Spec × Rep. Positive and compile-negative probes pass
on DMD 2.111 and LDC 1.41.

Concrete declaration syntax, validation traits, derived dimensions and Spec
hierarchies remain open.

### Questions

- how much semantic distinction belongs in the generic library;
- whether specification relationships need a hierarchy;
- whether the added type/compile-time cost is justified by consumers;
- how this interacts with `geo-d`/`geo3-d` Point/Vector semantics.

## R06 — Affine quantities and points

Research only. Examples include absolute temperature and height/elevation-like
points relative to an origin.

Do not conflate affine point semantics with ordinary relative quantities.
Geodetic reference-frame semantics remain outside this library.

## R07 — Angles

Angles require separate treatment because radians are dimensionless in formal
dimensional analysis while software benefits from strong angle semantics.

Before adding angle units, audit existing `geodesy-d` angle/latitude/longitude
contracts and determine whether reuse, adaptation, or independence is correct.

## R08 — Runtime unit metadata

Static numerical quantities and runtime-parsed unit descriptions solve different
problems.

Runtime metadata for WKT/PROJJSON/UCUM/EPSG integration is deferred. If later
needed, it should not impose storage or dispatch cost on static quantities.

## R09 — Performance and compile-time cost

Zero-overhead is an evidence claim.

Measure at least:

- storage size/alignment;
- optimized arithmetic/code generation versus raw scalar baselines;
- conversion code generation;
- DMD/LDC compile time for increasing instantiation counts;
- executable/code-size effects where material.

Low-level tricks require measured justification.

## R10 — Consumer matrix

Use real or realistic consumers to prevent an abstract physics library from
emerging without need.

Initial consumers/reference cases:

- `geodesy-d`: ellipsoid axes, projected coordinates, false offsets, numerical
  tolerances;
- `geo-d` / `geo3-d`: distances and possible dimensional result types without
  weakening existing Point/Vector semantics;
- raster/imagery: model-space resolution may be angular or linear, proving that
  raster resolution itself is not synonymous with `Length`;
- future `proj-d`: dynamic CRS/axis/unit metadata as a deliberately separate
  layer.


## R11 — Static declaration and validation mechanics

### Question

Which D mechanism should implement the ADR 0002 structural contracts while
keeping user-defined Dimensions, Specs and Units lightweight and diagnostics
useful?

R11 is promoted by `docs/adr/0003-structural-declaration-validation.md`.

M1 uses ordinary user-defined D types plus structural compile-time traits and
explicit API-boundary `static assert` diagnostics. The full five-case negative
matrix passes on both DMD 2.111 and LDC 1.41. Inheritance, runtime registration
and declaration macros are not required by the static core.
