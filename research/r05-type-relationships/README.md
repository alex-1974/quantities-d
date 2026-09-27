# R05 — Static type relationship probe

Research-only probe for the M1 type structure. Nothing here is public API.

## Question

After ADR 0001 selected `Quantity!(Spec, Rep)`, what is the minimal static
relationship between Dimension, Spec and Unit?

Candidate relationship:

```text
Dimension

Spec
  -> Dimension
  -> canonical Unit

Unit
  -> Dimension
  -> exact rational scale relative to that Dimension's reference unit

Quantity!(Spec, Rep)
  -> stores Rep only
```

## Required invariants

1. A Spec has exactly one Dimension.
2. A Spec has exactly one canonical Unit.
3. The Spec canonical Unit has the same Dimension as the Spec.
4. A Unit has exactly one Dimension.
5. A Unit scale is an exact rational relationship to the Dimension reference
   unit for the M1 linear-unit domain.
6. Unit symbols, display names, localization and parsing are not required for
   numerical type identity.
7. Reference-system semantics remain outside Dimension, Spec and Unit.

## Consumer examples

The probe should be able to express without runtime metadata:

- Length / metre;
- Radius / metre;
- Height / metre;
- LinearResolution / metre-based canonical representation;
- distinct Units kilometre, international foot and US survey foot sharing the
  Length Dimension.

It must also prove that:

- Length and Radius remain different Quantity types despite sharing Dimension
  and canonical Unit;
- a Unit of the wrong Dimension cannot be used to construct a Quantity;
- Unit diversity does not change `Quantity!(Spec, Rep)` identity;
- `sizeof(Quantity!(Spec, Rep)) == Rep.sizeof` for representative Reps.

## Open questions deliberately excluded

This probe does not decide:

- the final declaration syntax for Dimensions, Specs or Units;
- derived-dimension algebra;
- Spec hierarchies/implicit semantic conversions;
- angle treatment;
- display symbols/names;
- runtime parsing;
- affine quantity points;
- public construction/conversion names.

The goal is to validate relationships before API syntax.
