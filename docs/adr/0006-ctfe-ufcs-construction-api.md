# ADR 0006 — CTFE- and UFCS-Friendly Quantity Construction

- Status: Accepted
- Date: 2026-09-27
- Decision scope: M1 public construction and scalar-access shape

## Context

ADR 0001–0005 define the semantic core:

- Quantity identity is `Quantity!(Spec, Rep)`;
- Spec, Unit and Dimension are distinct;
- declarations are structurally validated;
- exact Unit scale uses `ExactRatio`;
- conversion status and rounding policy are explicit.

R13 evaluated how those semantics should appear at normal D call sites.

The public API must be natural in D, support CTFE and UFCS, infer Rep from the
value, preserve explicit Spec/Unit meaning, and prevent bypassing Unit-aware
construction through a raw Quantity constructor.

## Decision

The M1 construction shape is based on a free function template that is also
naturally usable through UFCS:

```d
quantity!(Spec, Unit)(value)
value.quantity!(Spec, Unit)
```

Rep is inferred from `value`.

Representative examples:

```d
auto a = quantity!(Length, Metre)(12.5);
auto b = 12.5.quantity!(Length, Metre);

enum km = 1.0.quantity!(Length, Kilometre);
enum metres = km.inUnit!Metre;
```

The Unit must remain explicit at construction. Spec must remain explicit where
a Unit may serve multiple quantity semantics.

## Why Unit alone is insufficient

A Unit belongs to a Dimension, not to one unique Spec.

For example, metre may be used with:

- Length;
- Radius;
- Height;
- LinearResolution.

Therefore syntax such as:

```d
12.5.quantity!Metre
```

is not a generally valid M1 construction surface because it silently loses
Spec semantics.

## CTFE requirement

Representative static-core operations must work in CTFE.

R13 confirms on both baseline compilers:

- construction in `enum` expressions;
- canonical extraction;
- Unit extraction through `inUnit!Unit`;
- distinct Spec identities sharing one Unit.

CTFE support is a normative M1 API requirement, not an incidental property.

## UFCS requirement

Value-oriented public operations should compose naturally with UFCS where that
does not obscure semantics.

Construction:

```d
value.quantity!(Spec, Unit)
```

Extraction:

```d
q.inUnit!Unit
```

UFCS must not alter the underlying identity model from ADR 0001.

## Raw construction boundary

Direct external payload construction is not a public API.

External code must not be able to bypass Unit-explicit construction with:

```d
Quantity!(Spec, Rep)(rawValue)
```

The concrete implementation may use a private constructor and a module-private
trusted factory path.

Likewise, the canonical payload field is not publicly observable or mutable.

R13 confirms through a separate consumer module on both DMD 2.111 and LDC 1.41:

- public Unit-aware construction succeeds;
- raw Quantity construction is rejected;
- direct payload-field access is rejected.

## Boundary diagnostics

Invalid public construction must fail at the quantities-d API boundary with
intentional diagnostics.

R13 confirms compile-negative coverage for:

- mismatched Spec/Unit Dimension;
- invalid Spec declaration;
- invalid Unit declaration.

All tested cases are rejected with expected boundary diagnostics on both
baseline compilers.

## Alternatives considered

### Spec-centred factory wrapper

Conceptually:

```d
SpecFactory!Length.from!Metre(value)
```

Not selected. It requires extra wrapper machinery without improving compiler
feasibility, CTFE support or semantic safety.

### Unit-centred factory wrapper

Conceptually:

```d
UnitFactory!Metre.as!Length(value)
```

Not selected. It places Unit before quantity meaning and encourages API
machinery on otherwise simple structural Unit declarations.

### Unit-only UFCS construction

```d
value.quantity!Metre
```

Rejected as a general M1 form because Unit does not uniquely identify Spec.

## Normative constraints

1. M1 construction is Unit-explicit.
2. Spec remains explicit when Unit does not uniquely determine quantity meaning.
3. Rep is inferred from the construction value where practical.
4. Representative construction/extraction operations must work in CTFE.
5. Value-oriented operations should support UFCS where semantics remain clear.
6. External code cannot directly construct Quantity from a raw canonical
   scalar.
7. External code cannot directly access or mutate the canonical payload field.
8. Invalid Spec/Unit combinations fail at the public API boundary.
9. Quantity storage remains one Rep payload where permitted by the language.
10. User-defined Specs and Units do not require quantities-d-specific methods,
    base classes or mixins.

## Not decided by this ADR

This ADR does not freeze:

- final module names;
- exact spelling of scalar extraction accessors;
- checked/rounded conversion function names;
- mixed-unit arithmetic syntax;
- implicit conversion policy;
- semantic conversion between distinct Specs;
- affine quantity-point APIs.

These remain separate M1 design tasks.

## Evidence

R13 evidence is under:

`research/r13-public-api-ctfe-ufcs/`

Validated on:

- DMD 2.111;
- LDC 1.41.

Evidence includes:

- CTFE positive probes;
- UFCS positive probes;
- competing call-shape comparison;
- six compile-negative boundary-diagnostic cases;
- six multi-module visibility cases covering accepted public construction and
  rejected raw constructor/payload access.
