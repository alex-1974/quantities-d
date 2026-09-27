# quantities-d

`quantities-d` is a planned fundamental D library for strongly typed physical
quantities and units with zero-overhead static metadata.

The library was admitted from concrete geospatial consumer pressure: a numeric
scalar alone cannot state whether a length is expressed in metres, kilometres,
international feet, US survey feet, or another unit. Unit semantics must be
explicit rather than inferred from numeric magnitude.

## Status

**M1 static core is complete; M2 minimal linear-unit work is in validation. No stable public release exists yet.**

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
- compile-negative API-boundary tests;
- external-consumer tests on DMD 2.111 and LDC 1.41.

`float`, `real`, mixed-Rep conversion, arithmetic, affine quantity points, and
runtime-parsed unit metadata are not yet production-complete.

The M1 branch-level compile-negative, external-consumer, DMD, and LDC gates
have passed. The API remains pre-release while M2 adds the first standard
linear-unit catalogue and further consumer validation.

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
