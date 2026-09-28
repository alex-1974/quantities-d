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


## Observed result

The complete semantic-resolution probe passed in all four baseline
configurations:

- DMD 2.111 debug: pass;
- DMD 2.111 release: pass;
- LDC 1.41 debug: pass;
- LDC 1.41 release: pass.

All runs exited with status 0.

The compile-time assertions confirm:

- Length opts into the common closed-additive case;
- Radius and Elevation do not gain arithmetic from same Dimension or same Spec;
- Length + Length resolves to Length;
- Length - Length resolves to Length;
- Length/Radius cross-Spec operations resolve to void;
- Radius/Radius resolves to void;
- an explicit research-local Elevation - Elevation relationship resolves to
  Length without changing the operator-facing SubResult query.

## R04.8 conclusion

The two-layer semantic model is viable on both baseline compilers:

1. a Spec-local common-case declaration supplies normative semantic intent;
2. AddResult/SubResult are the stable relationship query layer used by
   arithmetic operators.

The marker is declaration sugar, not the arithmetic API.

This preserves an extension path for future explicit cross-Spec or
different-result relationships without teaching operators about each
declaration mechanism.

No Quantity representation or Rep type participates in relationship
resolution, confirming that semantic result derivation can remain independent
from representation result derivation.

## Promotion direction

For the first M3 Length slice:

- Length may declare same-Spec closed additive semantics;
- production + and - should constrain on AddResult/SubResult;
- cross-Spec relationships remain absent;
- no general capability list or open relationship registry is needed.

The next semantic question is scalar closure. It should be decided separately
rather than inferred from additive closure.
