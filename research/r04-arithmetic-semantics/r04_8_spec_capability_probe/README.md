# R04.8.1 — Spec result-trait capability probe

## Goal

Test the R04.8 semantic query design independently of Quantity representation
and ResultRep arithmetic.

The operator-facing semantic API is:

- `AddResult!(Lhs, Rhs)`;
- `SubResult!(Lhs, Rhs)`.

A non-void result authorizes the semantic operation and identifies its result
Spec.

## Probe model

- Length opts into same-Spec closed additive value semantics.
- Radius does not.
- Elevation does not opt into same-Spec closure.
- an explicit future-style relation demonstrates
  `Elevation - Elevation -> Length`.

The explicit relation is research-local. The probe tests extension shape, not
a final public registration API.

## Required results

```text
AddResult!(Length, Length)       == Length
SubResult!(Length, Length)       == Length

AddResult!(Length, Radius)       == void
SubResult!(Length, Radius)       == void

AddResult!(Radius, Radius)       == void
SubResult!(Radius, Radius)       == void

AddResult!(Elevation, Elevation) == void
SubResult!(Elevation, Elevation) == Length
```

This proves that same-Spec identity alone grants nothing and that a later
explicit result relation can coexist with the common closed-value marker.

## Design requirement

Arithmetic operators must depend on AddResult/SubResult, never directly on the
marker. The marker is declaration sugar only.
