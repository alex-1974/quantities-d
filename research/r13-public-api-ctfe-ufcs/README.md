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
