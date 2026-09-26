# R01 — Static representation probe

Research-only probe for quantities-d issue #1. Nothing in this directory is public API.

## Candidates

- A: `QuantityA!(Unit, Rep)` — source-unit-preserving type identity.
- B: `QuantityB!(Spec, Unit, Rep)` — source-unit-preserving identity plus quantity specification.
- C: `QuantityC!(Spec, Rep)` — canonical-storage candidate; source unit is conversion-boundary metadata rather than value type identity.

## Controlled questions

The first probe deliberately keeps arithmetic minimal and compares:

1. value storage size and alignment against `Rep`;
2. type identity produced by changing unit and/or specification;
3. CTFE construction/extraction;
4. `@safe pure nothrow @nogc` construction/extraction;
5. whether a unit can be represented without a runtime field.

Later probe commits add equivalent arithmetic, conversions, compile-negative cases, consumer call sites, code generation, and compile-time scaling. Those should not be mixed into the representation baseline.

## Run

```bash
cd research/r01-static-representation
dub run --compiler=dmd --force
dub run --compiler=ldc2 --force
```

The executable contains compile-time assertions; success is the baseline result. Compiler/version and later performance measurements must be recorded separately rather than inferred from source shape.
