# quantities-d

`quantities-d` is a planned fundamental D library for strongly typed physical
quantities and units with zero-overhead static metadata.

The library was admitted from concrete geospatial consumer pressure: a numeric
scalar alone cannot state whether a length is expressed in metres, kilometres,
international feet, US survey feet, or another unit. Unit semantics must be
explicit rather than inferred from numeric magnitude.

## Status

**M1 static core in active development. No stable public API exists yet.**

The repository now contains the first production quantity core plus an
experimental checked-conversion implementation promoted from R14 research.

Current production coverage includes:

- canonical `Quantity!(Spec, Rep)` storage with zero runtime Unit/Spec metadata;
- exact compile-time rational Unit scales;
- CTFE- and UFCS-friendly canonical construction/extraction;
- explicit checked / exact-required / rounded non-canonical conversion for
  signed `long`;
- checked / exact-required non-canonical conversion for binary64 `double`;
- compile-negative API-boundary tests;
- external-consumer tests on DMD 2.111 and LDC 1.41.

`float`, `real`, mixed-Rep conversion, arithmetic, affine quantity points, and
runtime-parsed unit metadata are not yet production-complete.

The public API remains pre-stable while these M1 contracts are being validated.

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

The first M1 static-core slice is under implementation on
`feat/m1-static-core`.

The implemented slice is intentionally narrow and follows ADR 0001–0006:

```d
enum distance = 1.25.quantity!(Length, Kilometre);
static assert(distance.canonicalValue == 1250.0);
static assert(distance.inUnit!Kilometre == 1.25);
```

Non-canonical Unit conversion for integral Reps is deliberately not enabled
until the checked/rounding conversion machinery from ADR 0005 is implemented.
No silent integer truncation is permitted.
