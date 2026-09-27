# R13 — Public API shape: CTFE and UFCS

Research-only M1 API probe.

## Goal

Select a public M1 call shape only after exercising it as normal D code.

The API must preserve the semantics fixed by ADR 0001–0005 while being:

- naturally usable with UFCS;
- usable in CTFE;
- `@safe pure nothrow @nogc` for the static core where the operation permits;
- friendly to type inference;
- explicit at Unit boundaries;
- free of ambiguous raw-scalar construction;
- suitable for thin typed boundaries around scalar numerical kernels.

## Hard gates

### CTFE

Representative construction, extraction and exact conversion must work in
`enum`/compile-time expressions.

### UFCS

Operations on an existing Quantity should read naturally as D:

```d
q.inUnit!Metre
q.convertTo!OtherSpec
```

or an equally clear alternative.

UFCS must not force Unit identity into `Quantity!(Spec, Rep)`; ADR 0001 remains
unchanged.

### No ambiguous scalar constructor

This must not become the public meaning:

```d
Quantity!(Length, double)(12.0)
```

because the Unit of `12.0` is unstated.

Construction must name a Unit or use an explicitly canonical-only entry point.

## Candidate call sites

The probe evaluates shapes equivalent to:

```d
auto a = quantity!Metre(12.5);
auto b = 12.5.quantity!Metre;

enum c = 1L.quantity!Kilometre;
enum metres = c.inUnit!Metre;

auto canonical = a.canonicalValue;
```

The exact names are provisional.

## Questions

1. Is free-function + UFCS construction clearer than a static factory?
2. Should `quantity!Unit(value)` infer Spec from Unit, or must Unit name a
   default Spec?
3. Because one Dimension can have several Specs (Length, Radius, Height), is
   Unit-only construction semantically under-specified?
4. Is the safer constructor therefore `quantity!(Spec, Unit)(value)`?
5. Should a convenience constructor exist only for a generic base Spec such as
   Length?
6. What is the least surprising accessor for canonical scalar extraction?
7. Which conversions return a scalar in a requested Unit versus a new Quantity?
8. How should checked/rounded conversions compose with UFCS?

## Initial semantic warning

ADR 0002 deliberately separates Unit from Spec. Therefore Unit alone cannot in
general determine Quantity semantics.

For example, metre can measure Length, Radius, Height or LinearResolution.
Consequently:

```d
12.0.quantity!Metre
```

is attractive UFCS syntax but is not automatically semantically sufficient.

R13 must not trade ADR 0002's semantic distinction for shorter syntax.


## First probe result — 2026-09-27

The initial free-function/UFCS candidate builds, links and runs successfully on
both baseline compilers:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

Confirmed:

- CTFE construction works;
- CTFE extraction through `inUnit!Unit` works;
- UFCS construction works;
- Spec remains explicit at construction;
- same Unit can be used with distinct Specs without changing Quantity identity;
- zero-overhead storage remains intact for the representative probe.

This confirms feasibility only. It does not yet select the final public call
shape.

## Competing API shapes for the next gate

### A — free-function / UFCS construction

```d
auto q = quantity!(Length, Metre)(12.5);
auto q = 12.5.quantity!(Length, Metre);
```

Strengths:

- natural UFCS;
- explicit Spec and Unit;
- ordinary function template inference for Rep.

Cost:

- two template arguments at every non-canonical construction site.

### B — Spec-centred factory

Conceptually:

```d
auto q = Length.quantity!Metre(12.5);
```

or an equivalent compile-time factory vocabulary.

Potential strength:

- visually groups semantic meaning before Unit.

Potential cost:

- D does not provide namespace-like static methods on arbitrary user-defined
  Spec types without additional declaration machinery;
- may require mixins/helpers that conflict with ADR 0003's deliberately simple
  structural declaration model.

### C — Unit-centred factory

Conceptually:

```d
auto q = Metre.quantity!Length(12.5);
```

This remains semantically explicit but puts measurement Unit before quantity
meaning. It also risks encouraging Unit declarations to accumulate API
machinery that belongs to quantities-d rather than user-defined Unit metadata.

### Current bias

A remains the least intrusive candidate because it preserves ordinary structural
Spec/Unit declarations and gives UFCS naturally. B and C must demonstrate a
material usability benefit before adding declaration or mixin machinery.


## Competing-shape result — 2026-09-27

All three construction shapes build, link and run successfully on both baseline
compilers:

- DMD 2.111: PASS;
- LDC 1.41: PASS.

Therefore the alternatives provide no compiler-feasibility advantage.

### Selection candidate

Shape A remains the preferred M1 surface:

```d
quantity!(Spec, Unit)(value)
value.quantity!(Spec, Unit)
```

Reasons:

1. It preserves ADR 0003 structural declarations without adding mixins or
   wrapper-factory types.
2. It is naturally UFCS-compatible.
3. It works in CTFE.
4. Rep is inferred from the value.
5. Spec and Unit remain explicit and independent as required by ADR 0002.
6. User-defined Specs and Units do not need quantities-d-specific methods.
7. It minimizes public API machinery.

Spec-centred and Unit-centred wrapper factories are therefore not selected
unless later consumer evidence demonstrates a material usability benefit.

### Final gate before promotion

Before accepting the call shape, R13 still requires compile-negative coverage
for:

- mismatched Spec/Unit Dimension;
- invalid Spec declaration;
- invalid Unit declaration;
- attempts to bypass Unit-explicit construction;
- CTFE use of valid construction/extraction.

Diagnostics should fail at the quantities-d API boundary, not as deep template
errors.
