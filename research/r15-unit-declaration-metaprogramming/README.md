# R15 — Unit Declaration Metaprogramming

Status: active research

Issue: #10

## Question

How much D metaprogramming should quantities-d use for static Unit declaration
and catalogue construction?

The objective is not maximum metaprogramming. The objective is the smallest
mechanism that removes real boilerplate while preserving visible exact
semantics, useful diagnostics, CTFE, and acceptable compile-time cost.

## Baseline

M1 is accepted and merged to `develop`.

Production Unit declarations currently use the structural contract:

```d
struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}
```

This is candidate A and the control against which every abstraction is judged.

## Reference set

Every viable candidate must represent exactly:

| Unit | Exact scale in metres |
| --- | ---: |
| metre | 1 / 1 |
| kilometre | 1000 / 1 |
| centimetre | 1 / 100 |
| millimetre | 1 / 1000 |
| international foot | 381 / 1250 |
| US survey foot | 1200 / 3937 |

The foot definitions are deliberately non-decimal controls.

## Candidates

### A — explicit structs

Control. Maximum transparency, maximum repeated declaration structure.

### B — Unit template / alias

Investigate whether a normal template can own the repeated structural contract
while leaving Dimension and exact ratio visible at the declaration site.

### C — exact SI-prefix composition

Investigate a compile-time decimal-prefix mechanism based entirely on exact
integer/rational arithmetic. Treat this as a possible complement to A/B rather
than assuming it should define every Unit.

### D — descriptor-driven declaration

Investigate whether a descriptor adds enough value for family enumeration,
metadata, generated validation, or later symbols to justify another abstraction
layer.

### E — mixin / string mixin

Challenger only. Reject unless it solves a concrete requirement materially
better than templates, aliases, traits, `static if`, and `static foreach`.

## Experiments

1. declaration/readability probe;
2. structural validation probe;
3. exact scale/normalization probe;
4. Unit-family `AliasSeq` probe;
5. pairwise `static foreach` matrix;
6. compile-negative diagnostic comparison;
7. CTFE and attribute probe;
8. public type-name / diagnostic inspection;
9. DMD/LDC compile-time comparison where candidates materially differ;
10. optional symbol/name metadata boundary probe.

## Guardrails

- no runtime Unit registry;
- no unit parsing or formatting;
- no floating Unit definitions;
- no broad SI catalogue;
- no change to `Quantity!(Spec, Rep)` storage;
- no string mixin merely to reduce line count;
- no claim of compile-time or zero-overhead superiority without measurement.

## Promotion gate

For each candidate record:

- KEEP — suitable as the primary M2 mechanism;
- COMPLEMENT — useful for a narrower role;
- REJECT — worse than a simpler mechanism;
- DEFER — potentially useful but not justified by M2.

M2 production work starts only after this comparison has a clear result.


## A/B evidence — 2026-09-27

Both candidate A (explicit structs) and candidate B (Unit template + aliases)
compile successfully with DMD 2.111 and LDC 1.41 for the full six-Unit
reference set.

### Type identity / diagnostics

The compilers preserve the explicit struct name for A:

```text
A type: AGood
```

For B, the alias name is not preserved in `.stringof` or representative
diagnostics:

```text
B alias: Unit!(LengthDimension, 1000L, 1L)
B instantiated type: Unit!(LengthDimension, 1000L, 1L)
```

This is a material public-diagnostics cost: a consumer using a named
`Kilometre` alias can still be shown the implementation template
instantiation rather than the domain name.

### Invalid scale diagnostics

A zero denominator in A reports directly through `ExactRatio!(1L, 0L)` at
the declaration site.

B reports the same `ExactRatio` failure but adds another template
instantiation layer through `Unit!(LengthDimension, 1L, 0L)`.

The candidate-B `static assert(D != 0)` does not improve the observed error
because instantiation of the nested `ExactRatio` still supplies the operative
diagnostic. Duplicating that invariant in the wrapper therefore has no
demonstrated value.

### Invalid Dimension shape

A malformed explicit Unit can reach a structural boundary and produce a
domain-oriented diagnostic such as:

```text
Unit must provide Dimension
```

B makes the Dimension template argument syntactically mandatory, which rejects
a value such as `42`, but the resulting diagnostic is template-oriented:

```text
template instance Unit!(42, 1, 1) does not match template declaration ...
```

That is useful compiler enforcement, but it does not establish that B has
better domain diagnostics.

### Interim conclusion

- **A — KEEP as the semantic/diagnostic baseline.**
- **B — DEFER as a primary public Unit declaration mechanism.**

B removes repeated declaration structure, but current evidence shows two costs:
public compiler-visible type names become template instantiations and invalid
declarations gain an extra instantiation layer. No runtime or semantic benefit
has been demonstrated.

This does not reject templates as implementation tools. It rejects the current
idea that all public named Units should merely be aliases of one generic
`Unit!(Dimension, N, D)` type.

The next experiment evaluates exact SI-prefix metaprogramming as a narrower
**complement** to named Unit declarations.


## C evidence — 2026-09-27

Candidate C keeps public Units as explicit named structs and uses
metaprogramming only to derive exact decimal SI scales.

Both DMD 2.111 and LDC 1.41 compile the candidate successfully.

Observed compiler-visible names:

```text
C metre type: Metre
C kilometre type: Kilometre
C kilometre scale: ExactRatio!(1000L, 1L)
```

This preserves the domain-facing Unit type identity while moving only the
mechanical power-of-ten construction behind a template.

The candidate also validates:

- exponent 0 -> 1/1;
- positive exponents -> exact integer powers of ten;
- negative exponents -> exact reciprocal powers of ten;
- equivalence with explicit ExactRatio definitions;
- explicit non-SI ratios remain available unchanged;
- international foot and US survey foot remain exact and distinct;
- power-of-ten construction can reject values beyond the long-backed
  ExactRatio range before multiplication overflow.

### Interim conclusion

- **C — COMPLEMENT.**

C is promising as an implementation helper for exact SI-prefix scales, not as a
replacement for named Unit declarations.

The current strongest composition is therefore:

- explicit public Unit structs for type identity and diagnostics;
- exact compile-time helpers for mechanical scale construction;
- explicit ExactRatio definitions for non-SI or otherwise normative exact
  ratios.

The next candidate tests whether a descriptor layer adds enough value for
catalogue enumeration, metadata, or generated validation to justify its
additional abstraction.


## D evidence — 2026-09-27

Candidate D introduced a descriptor layer in addition to named public Unit
types.

Both DMD 2.111 and LDC 1.41 compile the descriptor candidate successfully.

Observed names:

```text
D public kilometre type: Kilometre
D descriptor alias: UnitDescriptor!(Kilometre, LengthDimension, 1000L, 1L)
D descriptor unit type: Kilometre
```

The public Unit type remains clean, but the descriptor itself is a template
instantiation and repeats normative information already stored by the Unit
type.

A descriptor-free control using only:

```d
alias LengthUnits = AliasSeq!(
    Metre, Kilometre, Centimetre, Millimetre,
    InternationalFoot, USSurveyFoot
);
```

successfully generates the same Unit-family validation and the same 6 x 6
pairwise matrix with `static foreach` on both baseline compilers.

Observed descriptor-free names:

```text
D-control public kilometre type: Kilometre
D-control catalogue entry: Kilometre
```

### Conclusion

- **D — REJECT for M2.**
- **AliasSeq + static foreach — COMPLEMENT.**

The descriptor adds no demonstrated capability required by M2. It duplicates
Dimension/Scale data and creates another template identity while the Unit types
themselves are already sufficient catalogue entries.

A descriptor layer may be reconsidered later only if a concrete requirement
cannot be represented naturally by the Unit types plus compile-time sequences,
for example metadata whose ownership genuinely belongs to a separate catalogue.

## Decision matrix after A-D

| Candidate | Result | Evidence |
| --- | --- | --- |
| A — explicit named structs | KEEP | Best public type identity and diagnostics; single visible source of normative Unit semantics. |
| B — generic Unit template aliases | DEFER | Removes declaration boilerplate but exposes template instantiations in type names/diagnostics and adds template error layers. |
| C — exact SI-prefix scale helper | COMPLEMENT | Preserves named public types while removing mechanical decimal-scale construction; exact rational result. |
| D — descriptor catalogue | REJECT | Descriptor-free AliasSeq/static foreach provides the required catalogue/test generation without duplicated semantics. |
| AliasSeq/static foreach | COMPLEMENT | Generates family and pairwise compile-time validation directly from Unit types. |

### Emerging M2 shape

The evidence currently favors:

1. public Units are explicit named structs;
2. each Unit owns its Dimension and exact Scale;
3. exact compile-time helpers may derive mechanical scales such as SI powers of
   ten;
4. Unit families are ordinary compile-time sequences of those Unit types;
5. generated validation/tests use `static foreach`;
6. no separate descriptor layer is introduced without a new proven
   requirement.

Candidate E remains only as a challenger: mixin or string-mixin declaration
generation must demonstrate a concrete advantage over this simpler shape.
