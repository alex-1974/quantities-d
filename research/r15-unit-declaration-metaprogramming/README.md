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


## E evidence — 2026-09-27

Candidate E was split into two mechanisms because D treats them very
differently:

- E1: a mixin template injects the structural Unit members into a normal,
  explicitly named struct;
- E2: a string mixin generates the declaration from source text.

Both compile successfully with DMD 2.111 and LDC 1.41.

Observed names:

```text
E1 metre type: Metre
E1 kilometre type: Kilometre
E1 kilometre scale: ExactRatio!(1000L, 1L)
E2 generated type: StringMixinKilometre
```

### E1 diagnostics

For an invalid zero denominator, both baseline compilers report the normal
`ExactRatio` invariant and point into the mixin template member:

```text
ExactRatio denominator must not be zero.
... instantiated from here: ExactRatio!(1L, 0L)
alias Scale = ExactRatio!(N, D);
```

This adds one implementation indirection compared with fully explicit A, but
the diagnostic remains an ordinary source location with the operative
`ExactRatio` failure intact. Public type identity remains the named struct.

### E2 diagnostics

The equivalent string-mixin failure reports a synthetic generated-source
location:

```text
negative_e.d-mixin-29(29)
```

LDC additionally echoes the generated declaration text. This is materially
worse for source navigation, diagnostics, refactoring, and maintenance than a
normal mixin template. No capability required by M2 was demonstrated that
requires source-string generation.

### Conclusion

- **E1 mixin template — COMPLEMENT.**
- **E2 string mixin — REJECT for M2.**

E1 is viable when a repeated structural declaration becomes large enough to
justify a shared mixin template while preserving nominal Unit types.

However, the current Unit contract contains only two aliases
(`Dimension`, `Scale`). Therefore E1 should not automatically replace the
explicit A form. The production choice should favor whichever form makes the
normative Unit definition clearest at the declaration site.

E2 fails the promotion rule: it adds diagnostic and tooling cost without a
demonstrated capability unavailable to ordinary D metaprogramming.

## Final R15 decision

| Mechanism | Result | M2 role |
| --- | --- | --- |
| Explicit named Unit structs | KEEP | Primary public Unit representation and semantic baseline. |
| Generic Unit template aliases | DEFER | Do not use as primary public Unit type mechanism. |
| Exact SI-prefix scale helper | COMPLEMENT | Use for exact mechanical decimal-scale construction where useful. |
| Descriptor catalogue | REJECT | Unit types + compile-time sequences already provide the required catalogue behavior. |
| AliasSeq/static foreach | COMPLEMENT | Use for Unit families and generated compile-time validation/test matrices. |
| Mixin template | COMPLEMENT | Optional declaration helper if repeated structural boilerplate grows enough to justify it. |
| String mixin | REJECT | No M2 requirement justifies generated-source diagnostics/tooling cost. |

## M2 recommendation

R15 promotes the following design constraints into M2:

1. **Public Units remain nominal named structs.**
   Compiler-visible domain names such as `Kilometre` are part of API quality.

2. **The Unit type is the single normative source of Dimension and exact Scale.**
   Do not duplicate those facts in a descriptor catalogue.

3. **Use normal D metaprogramming around, not instead of, the semantic type.**
   Preferred tools are templates, alias templates, `static if`,
   `static foreach`, and traits.

4. **Exact SI-prefix construction may be metaprogrammed.**
   Prefix helpers must produce `ExactRatio` values using integer/rational
   arithmetic only and must detect representational overflow.

5. **Unit families are compile-time sequences of Unit types.**
   Generate family invariants and pairwise conversion tests with
   `AliasSeq`/`static foreach`.

6. **Mixin templates remain optional.**
   If the Unit contract stays as small as `Dimension` + `Scale`, explicit
   aliases may remain clearer. A mixin becomes justified only when it removes
   meaningful repeated structure without obscuring normative definitions.

7. **Do not use string mixins for Unit declaration in M2.**
   Reconsider only if a future requirement cannot be expressed reasonably with
   normal templates and traits.

8. **Do not promote broad metadata/runtime catalogue features from R15.**
   Symbols, parsing, formatting, UCUM, serialization, and runtime registries
   remain deferred.

## Research status

R15 is complete for the M2 entry decision.

The next implementation step is to define the minimal M2 linear-unit slice
using the selected shape and then run the normal DMD/LDC, compile-negative,
CTFE, and consumer gates.
