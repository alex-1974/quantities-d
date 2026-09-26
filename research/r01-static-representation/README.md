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


## Baseline result — 2026-09-27

Corrected baseline probe passed with both supported compiler baselines:

- DMD 2.111: build/link/run PASS;
- LDC 1.41: build/link/run PASS.

The baseline therefore does not discriminate A/B/C: each candidate can satisfy the
tested zero-storage, type-identity, CTFE, and attribute constraints. This is a
necessary result, not a design selection.

The first attempted run used an invalid `std.traits.isSame` assumption. That was
a probe error and was replaced by D's built-in `is(T == U)`; it is not evidence
against any candidate.


## Geodesy consumer result — 2026-09-27

A projection-boundary probe derived from current geodesy-d semantics passed on DMD
2.111 and LDC 1.41.

The probe exposes a policy distinction rather than a feasibility distinction:

- B can encode one caller-selected linear unit across an operation and reject
  mixed-unit projection parameters statically.
- C can accept explicitly constructed quantities from different source units
  and canonicalize them before the numerical operation.

Neither result selects B or C. It establishes that choosing between them changes
public boundary semantics, not merely internal representation.

### Interim R01 assessment

- A remains useful as a minimal representation reference, but by itself has no
  independent quantity-specification axis and therefore cannot express the
  Length/Radius distinction tested here.
- B and C both satisfy the baseline D constraints tested so far.
- B versus C requires additional consumer and cost evidence before selection:
  geometry, raster/imagery, optimized code generation, and compile-time scaling.


## Geometry consumer result — 2026-09-27

A geo-d/geo3-d-oriented integer-coordinate probe passed on DMD 2.111 and
LDC 1.41 after an unrelated CTFE conversion assumption was removed from the
gate.

The relevant result is narrower than an argument for either representation:

- B can retain source-unit integral coordinates and permit exact differencing
  before later metric floating-point conversion.
- C can retain the same property when its canonical unit is represented
  exactly by an integral Rep.
- Canonical storage therefore does not by itself destroy the integer-coordinate
  exactness relied on by geo-d/geo3-d.
- Loss introduced by changing Rep or by a non-integral source-to-canonical
  conversion is a conversion/exactness-policy concern and must be resolved by
  R02/R03.

The failed CTFE cast assumptions are recorded as harness findings, not quantity
representation evidence.
