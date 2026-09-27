# R11 — Static declaration and validation mechanics

Research-only probe for M1 declaration mechanics. Nothing here is public API.

## Question

ADR 0002 fixes the semantic relationships, but not how D code declares or
validates them. Which mechanism gives quantities-d:

- user-definable Dimensions, Specs and Units;
- no inheritance or runtime registration requirement;
- compile-time structural validation;
- useful diagnostics at the public API boundary;
- zero per-value metadata;
- compatibility with DMD 2.111 and LDC 1.41?

## Candidate direction

Use ordinary user-defined types with required compile-time members:

```d
struct LengthDimension {}

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

Library traits validate the structural contract rather than requiring a base
type or registration macro.

## Probe questions

1. Can traits inspect valid declarations without producing diagnostics?
2. Can public templates reject invalid declarations with a short explicit
   `static assert` message?
3. Can validation distinguish:
   - missing Spec.Dimension;
   - missing Spec.CanonicalUnit;
   - mismatched Spec/Unit Dimension;
   - missing Unit.Dimension;
   - missing Unit.Scale;
   - malformed exact ratio?
4. Do valid paths remain CTFE-capable and zero-storage?
5. Are diagnostics reasonably similar on DMD and LDC?

## Deliberate non-decisions

This probe does not freeze public names such as `isQuantitySpec`,
`validateQuantitySpec`, or `ExactRatio`. It evaluates the mechanism.

It also does not decide derived dimensions, arithmetic, formatting, runtime
parsing, angle semantics, or Spec hierarchies.


## Diagnostic harness correction — 2026-09-27

The first diagnostic run established:

- all five DMD negative cases were rejected with the intended boundary
  diagnostic;
- the initial LDC portion was invalid because the runner passed DMD's
  `-version=Name` syntax to LDC.

LDC expects `-d-version=Name`. The runner was corrected to select the
compiler-specific version flag. No conclusion about LDC diagnostics is drawn
from the invalid first run; it must be rerun with the corrected harness.


## Corrected diagnostic result — 2026-09-27

With compiler-specific version flags, the full negative matrix passes:

- DMD: 5/5 cases rejected with the intended API-boundary diagnostic;
- LDC: 5/5 cases rejected with the intended API-boundary diagnostic.

The structural trait + explicit boundary `static assert` mechanism is therefore
confirmed on both baseline compilers and promoted by ADR 0003.
