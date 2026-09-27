# ADR 0003 — Structural Declaration and Validation Mechanics

- Status: Accepted
- Date: 2026-09-27
- Decision scope: M1 declaration/validation mechanism

## Context

ADR 0002 fixed the semantic relationships between Dimension, Spec, Unit and
Quantity, but deliberately left the concrete D mechanism open.

R11 evaluated a lightweight structural approach using ordinary user-defined
types with compile-time members, for example:

```d
struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}
```

Library traits inspect these structural contracts without requiring inheritance,
runtime registration or generated declaration macros.

The positive probe builds and runs on DMD 2.111 and LDC 1.41. The diagnostic
matrix verifies five invalid declarations on each compiler:

- missing Spec.Dimension;
- missing Spec.CanonicalUnit;
- wrong CanonicalUnit Dimension;
- missing Unit.Dimension;
- missing Unit.Scale.

All ten invalid cases are rejected with the intended API-boundary diagnostic.

## Decision

M1 uses ordinary D user-defined types plus structural compile-time validation.

The library may expose traits/concepts equivalent to:

```text
isUnit!U
isQuantitySpec!S
```

Public templates that require valid Specs or Units perform explicit validation
at the API boundary and emit targeted `static assert` diagnostics rather than
allowing deep template-member failures to become the primary error surface.

No base class, interface, runtime registry or declaration macro is required for
a user-defined Dimension, Spec or Unit.

## Normative constraints

1. Dimension, Spec and Unit declarations are ordinary compile-time D types.
2. Validity is structural: a declaration is accepted because it satisfies the
   required compile-time contract, not because it inherits from a library base
   type.
3. Validation traits must be non-diagnostic predicates where practical.
4. Public API boundaries must convert invalid structural declarations into
   short, intentional diagnostics.
5. Validation must distinguish at least:
   - missing Spec.Dimension;
   - missing Spec.CanonicalUnit;
   - mismatched Spec/CanonicalUnit Dimension;
   - missing Unit.Dimension;
   - missing Unit.Scale;
   - malformed exact ratio where relevant.
6. Validation must not require runtime registration.
7. Validation machinery must not add per-value runtime storage.
8. User-defined Specs and Units remain possible without modifying the library.
9. DMD 2.111 and LDC 1.41 are normative baseline compilers for this mechanism.
10. Compiler-specific test harness details must not be mistaken for semantic
    failures; diagnostic tests must invoke each compiler with valid flags.

## Rationale

### Structural over nominal registration

The library models compile-time semantic relationships. Requiring inheritance or
registration would add ceremony without strengthening the actual invariant.

Structural validation keeps extension local:

```d
struct CustomUnit
{
    alias Dimension = SomeDimension;
    alias Scale = ExactRatio!(...);
}
```

If the declaration satisfies the contract, it can participate without a central
registry or library modification.

### Explicit boundary diagnostics

Raw template substitution failures often produce long diagnostics at incidental
member access sites. M1 instead treats diagnostics as part of API quality.

A predicate-style trait can safely answer whether a declaration is valid;
public templates then issue a targeted message when the predicate is false.

This gives callers a stable semantic failure point while retaining ordinary D
types internally.

## Consequences

### Positive

- User extensions remain lightweight and decentralized.
- No runtime metadata or registration machinery is introduced.
- The design follows normal D compile-time idioms.
- Invalid declarations fail near the public API boundary.
- Diagnostics are controllable and testable on both baseline compilers.
- Structural contracts remain compatible with zero-storage Quantity values.

### Costs

- Structural traits become part of the library's compile-time implementation
  surface and require careful maintenance.
- Error quality depends on deliberate boundary validation rather than template
  constraints alone.
- Public trait names and exact diagnostic wording become compatibility concerns
  if exposed.
- Very rich future declaration semantics may require additional validation
  layers.

## Alternatives considered

### Base classes/interfaces

Rejected for M1. They impose nominal coupling and do not improve compile-time
unit/spec invariants.

### Runtime registry

Rejected for the static core. It adds runtime state and belongs, if ever needed,
to a separate dynamic metadata layer.

### Declaration macros/string mixins

Not selected for M1. They may reduce boilerplate later, but are unnecessary to
establish correctness and would hide the underlying structural contract.

### Template constraints only

Insufficient as the primary diagnostic strategy. Constraints are useful for
overload participation, but alone may produce weaker or less intentional error
messages than explicit API-boundary validation.

## Not decided by this ADR

This ADR does not freeze:

- final public trait names;
- exact diagnostic wording;
- the public declaration helper syntax, if any;
- the concrete ExactRatio implementation;
- derived dimensions;
- arithmetic;
- Spec hierarchies;
- angle semantics;
- formatting/parsing;
- runtime metadata.

Those remain separate M1 or later decisions.

## Evidence

R11 positive probe:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

R11 compile-negative diagnostic matrix:

- DMD: 5/5 invalid cases rejected with intended boundary diagnostic;
- LDC: 5/5 invalid cases rejected with intended boundary diagnostic.

The research probe remains under
`research/r11-declaration-validation/`.
