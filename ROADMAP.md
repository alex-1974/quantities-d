# quantities-d Roadmap

## Planning rule

Research before abstraction. Semantic correctness before convenience. Measure
runtime and compile-time cost before claiming zero overhead.

## M0 — Repository and research baseline

Goal: establish a reproducible project home without prematurely freezing an API.

Acceptance:

- repository/DUB/module identity is consistent;
- DMD 2.111 and LDC 1.41 baseline CI exists;
- external root-import consumer exists;
- architecture boundaries and non-goals are documented;
- initial research questions and candidate designs are recorded.

## M1 — Static quantity core design

Resolve, with prototypes and evidence:

- `Quantity!(Unit, Rep)` versus `Quantity!(Spec, Unit, Rep)` versus canonical
  storage alternatives;
- compile-time representation of dimensions, quantity specifications, units,
  and exact scale ratios;
- storage layout and ABI expectations;
- arithmetic result rules;
- explicit conversion and loss/rounding policy;
- CTFE, `@safe`, `pure`, `nothrow`, and `@nogc` viability;
- compile-time cost on DMD and LDC.

No stable API commitment is implied until these questions are closed.

## M2 — Minimal linear-unit slice

Only after M1 decisions:

- metre;
- kilometre;
- millimetre/centimetre if consumer evidence justifies them;
- international foot;
- US survey foot;
- exact conversion factors;
- compile-negative dimensional/semantic tests;
- consumer probes from geodesy/geometry use cases.

## M3 — Quantity semantics and derived operations

Evaluate from real consumers:

- length versus distance/radius/height specifications;
- area and derived dimensions;
- mixed-unit arithmetic ergonomics;
- mathematical functions required by numerical libraries.

## Deferred until justified

- affine quantity points/origins;
- runtime unit parsing/metadata;
- UCUM parsing/formatting;
- serialization formats;
- CRS/reference-frame semantics;
- a broad SI/physics catalogue.
