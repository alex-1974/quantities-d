# quantities-d

`quantities-d` is a planned fundamental D library for strongly typed physical
quantities and units with zero-overhead static metadata.

The library was admitted from concrete geospatial consumer pressure: a numeric
scalar alone cannot state whether a length is expressed in metres, kilometres,
international feet, US survey feet, or another unit. Unit semantics must be
explicit rather than inferred from numeric magnitude.

## Status

**M1 static core and M2 minimal linear-unit work are complete. M3 is in progress and now includes promoted integral and floating arithmetic semantics, derived dimensions, exact product/quotient relations, qualified nontrivial floating canonical rescale, and the first explicit TargetRep conversion matrix. No stable public release exists yet.**

The repository now contains the first production quantity core and the checked
conversion contract accepted by ADR 0007.

Current production coverage includes:

- canonical `Quantity!(Spec, Rep)` storage with zero runtime Unit/Spec metadata;
- exact compile-time rational Unit scales;
- public M2 length catalogue: metre, kilometre, international foot, and US survey foot;
- CTFE- and UFCS-friendly canonical construction/extraction;
- explicit checked / exact-required / rounded non-canonical conversion for
  signed `long`;
- checked / exact-required non-canonical conversion for binary64 `double`;
- explicit `checkedQuantityAs` / `exactQuantityAs` / `roundedQuantityAs` and matching extraction requests for the selected R15 TargetRep matrix (`long` / `float` / `double` targets from represented `long` / `ulong` / `float` / `double` / qualified `real` sources);
- same-Spec integral and floating `+` / `-` under explicit representation-admission rules;
- symmetric scalar multiplication and promoted `Quantity / scalar` for scalable Specs;
- integral Class-W direct arithmetic plus Class-O64 `checkedAdd`, `checkedSub`, and `checkedMul`;
- named integral `exactDiv` and `exactMul` for value-dependent exact arithmetic;
- open canonical dimension algebra and exact derived-unit algebra, with `Area` / `SquareMetre` as the first production derived-dimension case;
- explicit semantic `Quantity * Quantity` and `Quantity / Quantity` result relations, including consumer-owned relation sets;
- native identity-rescale floating product/quotient paths;
- exact represented-source nontrivial binary32 and binary64 canonical rescale with one final rounding;
- conditional exact nontrivial D `real` rescale for the qualified binary64-like and real80-like trait sets;
- compile-negative API-boundary tests;
- external-consumer tests on DMD 2.111 and LDC 1.41.

M3 is not complete. Remaining research-first areas include conversion beyond the selected R15 TargetRep matrix (for example target `real` and further integral targets), general cross-Spec additive semantics, automatic/generic Dimensionless result semantics, mixed-unit arithmetic ergonomics, consumer-driven mathematical functions, affine quantity points, and runtime-parsed unit metadata.

M1 and M2 are complete. PR #15 promoted the first evidence-backed R04
arithmetic slice after DMD/LDC debug and release tests, external-consumer
validation, and compile-negative gates. The API remains pre-release while M3
continues research-first expansion.

## Intended domain

The library is intended to own reusable, application-independent concepts such
as:

- static quantity and unit representation;
- exact or loss-aware unit conversion;
- dimension and quantity-kind/specification relationships where justified;
- compile-time rejection of invalid operations;
- zero-overhead value semantics suitable for numerical kernels.

It does **not** own:

- CRS, datum, ellipsoid, projection, or reference-frame semantics;
- EPSG databases, WKT, PROJJSON, or operation discovery;
- raster georeferencing or pixel/model transforms;
- geoid or vertical-datum transformations;
- application-specific measurement policy.

Those semantics remain in their appropriate domain libraries.

## Initial engineering constraints

The first design work starts from these research-backed constraints:

1. physical units are never inferred from scalar magnitude;
2. dimension, quantity semantics, unit, and reference-system semantics are
   distinct concepts;
3. static unit metadata must not add per-value runtime storage;
4. exact unit definitions should remain exact for as long as practical;
5. potentially lossy conversions must be explicit;
6. strong types protect public/subsystem boundaries without forcing wrappers
   through every performance-sensitive scalar kernel;
7. runtime-parsed unit metadata is a separate concern from the static core;
8. API shape must be validated with real consumers before stabilization.

These are starting constraints, not a frozen API design. See `RESEARCH.md` and
`docs/architecture.md`.

## Package identity

```text
repository / DUB package: quantities-d
D module root:            quantities
license:                  MIT
minimum D frontend:       2.111.0
baseline compilers:       DMD 2.111.0, LDC 1.41.0
```

## Development

Daily integration happens on `develop`. `main` is reserved for release-quality
states. Research work may use purpose-specific `research/*` branches when it
needs longer-lived isolation.

Current baseline gates:

```bash
dub test --compiler=dmd --force
dub test --compiler=ldc2 --force
dub build --build=release --compiler=dmd --force
dub build --build=release --compiler=ldc2 --force

cd tests/consumer
dub run --compiler=dmd --force
dub run --compiler=ldc2 --force
```

## Workspace context

When checked out inside `d-geospatial-workspace/libs/quantities-d`, canonical
workspace documents are exposed locally through `.workspace/`. That directory
is intentionally ignored by Git and is not package content.


## M1 implementation status

The M1 static core and checked conversion slice follow ADR 0001–0007:

```d
enum distance = 1250.0.quantity!(Length, Metre);
static assert(distance.canonicalValue == 1250.0);
static assert(distance.inUnit!Metre == 1250.0);
```

Non-canonical Unit conversion is explicit. Integral conversion never silently
truncates or rounds; checked, exact-required, and explicitly rounded operations
carry the conversion intent.

Domain libraries do not need to depend on quantities-d merely because their
scalar APIs have documented canonical units. For example, a geodetic library
may define metres for linear scalars and strong angle types in its own contract.
A quantities-d integration should be an optional boundary adapter unless a
consumer demonstrates that quantities belong in its core model.


## M2 linear-unit slice

The M2 public length catalogue is intentionally minimal:

- `Metre`, the canonical unit of `Length`;
- `Kilometre`;
- `InternationalFoot`, exactly `381 / 1250` metre;
- `USSurveyFoot`, exactly `1200 / 3937` metre.

The current geospatial consumer audit found no concrete centimetre or
millimetre requirement. Those units are therefore not added speculatively;
they remain candidates for a later consumer-backed extension.

`geo-d` and `geo3-d` remain coordinate-system- and unit-agnostic.
`geodesy-d` documents metres as its normal linear convention. The current
audit therefore also does not justify a hard quantities-d dependency in those
libraries.


## M3 integral-arithmetic slice

PR #15 promotes the first evidence-backed R04 arithmetic decisions into the
production API.

For integral representations, same-Spec `Length` addition and subtraction and
symmetric multiplication by integral scalars are admitted only when both the
semantic Spec relationship and a result representation safe for the complete
operand type ranges are known. Operations for which no built-in result
representation can satisfy that invariant are not exposed as unchecked direct
operators.

Integral division is explicit through `exactDiv` rather than raw `/`.
`DivisionResult` distinguishes exact results, inexact division, and division
by zero without permitting contradictory public result states.

PR #17 extends that first slice on `develop` with an open canonical dimension
algebra, exact derived-unit scale algebra, `Area` / `SquareMetre`, and integral
`Quantity * Quantity` products. Product semantics remain explicit: Specs may
own a `ProductWith` / `ProductFromLeft` relation, while consumers that cannot
modify either operand Spec may provide an explicit compile-time relation set to
`product!Relations` or `exactMul!Relations`.

Direct integral product operations are exposed only when their complete operand
type ranges are representable and canonical storage requires no lossy rescale.
`exactMul` provides the value-dependent exact path for nontrivial canonical
rescaling and reports an inexact result rather than truncating.

This is not the completion of M3. The integral core has since been extended by
checked Class-O64 arithmetic and qualified floating arithmetic/rescale semantics.
General cross-Spec addition/subtraction, automatic Dimensionless semantics,
conversion beyond the selected R15 TargetRep matrix, and consumer-driven mathematical functions remain research-first work.


### M3 exact Quantity quotient slice

Integral Quantity/Quantity division is exposed through the named `exactDiv`
operation rather than unchecked `/`. Quotient semantics are explicit:
operand Specs may declare `QuotientWith` / `QuotientFromLeft`, while a
consumer that owns neither operand may provide an ordered
`Relations.Quotient!(Lhs, Rhs)` relation to `exactDiv!Relations`.

Physical quotient Dimension, exact Unit/canonical rescale, semantic ResultSpec,
and numeric ResultRep remain separate compile-time concerns. The ResultRep is
selected only when its complete positive and negative exact-result envelope is
representable by a built-in integral type. Runtime outcomes therefore remain
`exact`, `inexact`, or `divisionByZero`; representational range failure is
a compile-time gate.

A dimensionless physical quotient does not automatically become a raw scalar
or select a generic ratio Spec. It is supported only when an explicit semantic
ResultSpec with `Dimensionless` Dimension is supplied.
