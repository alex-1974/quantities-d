# ADR 0001 — Canonical Quantity Identity by Specification and Representation

- Status: Accepted
- Date: 2026-09-27
- Decision scope: M1 static quantity representation

## Context

The M1 research compared three static representations:

```text
A  Quantity!(Unit, Rep)
B  Quantity!(Spec, Unit, Rep)
C  Quantity!(Spec, Rep) with canonical storage
```

The representation must preserve semantic distinctions, add no per-value unit
metadata, support exact unit relationships and explicit conversion-loss policy,
remain usable from `@safe pure nothrow @nogc` code where the operation permits,
and scale acceptably on the supported DMD and LDC baselines.

R01 established that Unit and quantity specification are independent semantic
axes. A therefore cannot be the primary model: it cannot distinguish
same-dimension concepts such as Length and Radius independently of Unit.

B and C both satisfy the tested storage, CTFE and attribute feasibility
requirements. They differ in whether source Unit remains part of the stored
quantity's permanent type identity.

R02 established that canonicalization does not require silent loss. Exact unit
relationships can remain compile-time rational values, while value conversion
can separately distinguish exact-required, checked/loss-aware and explicitly
rounded intentions. B requires the same conversion policy when units are mixed.

R09 measured a compiler/type-instantiation scaling cost for B as Unit diversity
increases. DMD materializes type/runtime metadata for each concrete
`Quantity!(Spec, Unit, Rep)`; LDC also shows increasing compile-resource and
binary cost at larger instantiation counts. Current geospatial consumers need
Spec-level distinctions, but generally do not require source Unit to remain
part of value type identity after an explicit normalization boundary.

## Decision

The M1 static quantity identity is:

```d
Quantity!(Spec, Rep)
```

Each `Spec` defines one canonical Unit contract. Source Unit is compile-time
metadata supplied at explicit construction or conversion boundaries; it is not
stored as part of the quantity's permanent type identity.

A quantity stores only its `Rep` payload. Unit and Spec metadata must not add
per-value runtime storage.

## Normative constraints

1. Every Spec used by `Quantity` has one explicit canonical Unit.
2. A physical Unit is never inferred from scalar magnitude.
3. A raw scalar cannot enter a Quantity through an API whose source Unit is
   ambiguous.
4. Normatively exact Unit relationships remain exact compile-time rational
   values for as long as practical.
5. Unit algebra and value/Rep conversion remain separate concerns.
6. Integral conversion to canonical storage must not silently truncate, wrap or
   round.
7. Potential loss is represented by an explicit conversion intention.
8. Explicit rounding, where provided, is caller-selected value-conversion
   policy and is not Unit identity.
9. Full supported signed integral ranges must not rely on an invalid
   `abs(min)` step.
10. Domain/reference semantics such as CRS, datum, vertical reference frame and
    raster georeferencing remain outside generic Quantity identity.
11. Strong Quantity types protect semantic boundaries. Numerical kernels may
    explicitly extract canonical scalar values.
12. Representative Quantity storage/layout must continue to be verified against
    `Rep`; zero overhead is an evidence claim, not an assumption.

## Consequences

### Positive

- Concrete quantity type identity scales primarily with Spec and Rep rather
  than Spec, Unit and Rep.
- Mixed source Units can normalize at explicit boundaries without proliferating
  stored quantity types.
- Unit conversion policy is centralized rather than encoded implicitly in
  arithmetic between many Unit-bearing quantity types.
- The model fits the workspace rule of strong semantic boundaries and lean
  scalar numerical kernels.
- Existing geodesy angle types provide a domain-specific precedent for
  canonical internal representation with explicit source-unit boundaries.

### Costs

- The original source Unit is not recoverable from Quantity type identity after
  normalization.
- Canonical Unit becomes a durable part of each Spec contract.
- Integral Rep choices must be compatible with the Spec canonical Unit or
  construction can legitimately fail as inexact.
- Consumers that specifically require persistent source-unit identity need a
  separate representation or metadata layer rather than changing core
  Quantity identity.

## Alternatives

### A — Quantity!(Unit, Rep)

Rejected as the M1 primary model because Unit alone cannot represent the
independent quantity-specification semantics required by consumers.

### B — Quantity!(Spec, Unit, Rep)

Technically viable and semantically strong. Rejected for the M1 core because
persistent source-Unit identity has not shown sufficient consumer value to
justify the larger concrete type space and measured compiler/type-materialization
cost. B remains research evidence and may inform a future specialized
source-unit-preserving type if a real consumer requires one.

## Not decided by this ADR

This ADR does not select:

- public construction/conversion function names;
- the concrete Spec/Dimension/Unit declaration machinery;
- the minimal rounding-mode set;
- generic Rep support beyond demonstrated constraints;
- mixed-quantity arithmetic rules;
- derived dimensions/specifications;
- affine quantity points;
- angle integration;
- runtime unit parsing/metadata.

Those require their own M1 decisions or later milestones.

## Evidence

Primary research records:

- R01 static representation probes and geodesy/geometry/imagery consumers;
- R02 exact-ratio and conversion-intent probes;
- R09 DMD/LDC cost, scaling, TypeInfo isolation and real-consumer audit.

The research branches and issue history remain the detailed evidence trail.
