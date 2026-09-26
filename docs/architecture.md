# Architecture — Initial Constraints

## Status

This document records the architectural boundary established at repository
creation. It intentionally does not freeze the core public API.

## Domain boundary

`quantities-d` owns reusable static quantity/unit semantics. It does not own the
reference systems that give domain-specific meaning to measurements.

```text
quantity semantics        quantities-d
unit identity/conversion  quantities-d
exact scale relationships quantities-d

CRS / datum / projection  outside
vertical reference frame  outside
raster georeferencing     outside
EPSG/WKT/PROJJSON         outside
```

## Established starting constraints

### Units are explicit semantics

A physical unit must never be inferred from the magnitude of a scalar value.
An API either defines its unit contract or carries enough type/metadata to make
that unit explicit.

### Distinct semantic layers stay distinct

Dimension, quantity specification/kind, unit, and reference-system semantics are
not interchangeable concepts.

### Static metadata is zero-storage metadata

The static core should encode unit/specification information in types/templates,
not in per-object runtime fields. A representative quantity should be capable of
having the same storage size as its representation type; this must be verified,
not assumed.

### Exact definitions remain exact

Where a unit conversion is normatively exact, preserve an exact compile-time
relationship for as long as practical. Do not replace an exact rational
relationship with an approximate decimal merely for implementation convenience.

### Loss is explicit

Conversions that can truncate, narrow, overflow, or otherwise lose information
must not silently masquerade as value-preserving conversions.

### Strong boundaries, lean kernels

Strong quantity types should protect public and subsystem boundaries. Numerical
algorithms may operate on explicitly normalized scalar representations where
that produces simpler/faster kernels without weakening the external semantic
contract.

### Static and dynamic units are separate concerns

Runtime-parsed unit metadata may later be useful for CRS/serialization systems,
but it must not burden the static numerical core.

## Open design decisions

The following remain research questions and must not be treated as established
API:

- exact `Quantity` template parameters;
- canonical versus unit-preserving storage;
- mixed-unit arithmetic;
- dimension/specification representation;
- conversion syntax and rounding policy;
- affine quantity-point support;
- angle integration;
- dynamic-unit representation.

Decisions with durable API/representation consequences should be recorded in
`docs/adr/` before stabilization.
