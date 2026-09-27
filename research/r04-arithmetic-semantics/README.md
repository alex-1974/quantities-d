# R04 — Arithmetic Semantics

Status: research, not production API.

## Purpose

Determine which arithmetic relationships belong in `quantities-d` while preserving
the accepted `Quantity!(Spec, Rep)` canonical-storage architecture and the
distinction between Dimension, Spec, Unit, and Rep.

This research deliberately separates three questions:

1. Is the operation dimensionally valid?
2. Is the operation semantically valid for the participating Specs?
3. If valid, can the result Spec be derived without inventing domain meaning?

A positive answer to (1) does not imply a positive answer to (2) or (3).

## Baseline invariants

- Quantity identity is `Spec × Rep`.
- Spec owns Dimension and CanonicalUnit.
- Unit conversion is explicit at construction/extraction boundaries.
- Stored values are canonical.
- Arithmetic must not silently introduce a second conversion/loss policy.
- Spec is not inferred from Unit or scalar magnitude.
- Generic dimension algebra must not invent domain semantics.
- Public abstractions require consumer evidence.

## First semantic matrix

| Operation | Dimensional result | Spec question | Initial research classification |
|---|---|---|---|
| `Q<S,R> + Q<S,R>` | same Dimension | result can remain S | strong candidate |
| `Q<S,R> - Q<S,R>` | same Dimension | result can remain S only if S is difference-like | requires Spec audit |
| `Q<S,R> * scalar` | same Dimension | result can normally remain S | strong candidate |
| `Q<S,R> / scalar` | same Dimension | result can normally remain S | strong candidate; zero/loss policy separate |
| `Q<S1,R> + Q<S2,R>` | same Dimension if compatible | which Spec owns result? | reject by default pending explicit relation |
| `Q<S1,R> - Q<S2,R>` | same Dimension if compatible | result may be a third Spec | reject by default pending explicit relation |
| `Q<S1,R> * Q<S2,R>` | product Dimension | result Spec is not implied by dimensions | open |
| `Q<S1,R> / Q<S2,R>` | quotient/dimensionless | result Spec may be ratio-like or scalar | open |
| `sqrt(Q)` | exponent-halved Dimension | result Spec cannot generally be inferred | consumer-driven |
| `hypot(Q,Q)` | same Dimension | meaningful for some Specs, not all | consumer-driven |

## Why subtraction is not automatically symmetric with addition

For a generic relative quantity such as a reusable `Length`, preserving the
same Spec under subtraction is plausible.

For future affine or point-like semantics, however, subtraction can change the
semantic kind: point minus point yields a difference, while point plus point is
usually meaningless. R06 owns affine quantities, but R04 must avoid an
arithmetic design that makes later separation impossible.

Therefore M3 should initially reason about ordinary relative quantities only and
must not use their algebra as a universal law for all future Specs.

## Derived dimensions versus derived Specs

Dimension algebra can mechanically derive relationships such as:

- Length × Length -> Length²
- Area / Length -> Length
- Length / Length -> Dimensionless

That does **not** establish semantic results such as:

- Radius × Radius -> Area
- Distance × Height -> Area
- Width × Height -> Area
- Distance / Distance -> a particular ratio Spec

The library may eventually need two layers:

1. mechanical Dimension algebra;
2. explicit Spec result relationships.

R04 must test whether layer (2) is needed in the generic library or whether
consumer/domain libraries should own those relationships.

## Rep questions

Arithmetic also needs an independent result-Rep policy. Candidate directions:

A. require identical Rep;
B. use D's normal arithmetic result type;
C. define a quantities-specific promotion rule;
D. require explicit conversion when Reps differ.

This must be tested with signed/unsigned integers, float/double, overflow,
integer division, CTFE, and DMD/LDC diagnostics before promotion.

## First probes

The first implementation probes should compare, without yet modifying
production `Quantity`:

1. same-Spec addition/subtraction with identical Rep;
2. scalar multiplication/division;
3. mixed Rep behavior under ordinary D arithmetic;
4. a minimal mechanical Dimension product representation;
5. explicit versus inferred result-Spec mappings for Length × Length;
6. compile-negative cross-Spec arithmetic.

Each probe must record DMD 2.111 and LDC 1.41 behavior, CTFE viability,
attributes, diagnostics, and any measurable template/code-generation cost.

## Promotion gate

No arithmetic operator enters production until R04 can state:

- dimensional validity;
- Spec validity and result-Spec rule;
- Rep result rule;
- loss/overflow interaction with the M1 conversion contract;
- compile-negative behavior;
- CTFE/UFCS/attribute expectations;
- consumer justification for any derived Spec or math function.
