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

ADR 0001–0007 close the M1 storage, static metadata, conversion-intent,
CTFE/UFCS, and checked-conversion decisions. PR #9 merged the checked
conversion slice after DMD/LDC debug and release tests, compile-negative gates,
and external-consumer validation. M1 is complete.

## M2 — Minimal linear-unit slice

M2 begins from the accepted M1 core:

- metre;
- kilometre;
- millimetre/centimetre if consumer evidence justifies them;
- international foot;
- US survey foot;
- exact conversion factors;
- compile-negative dimensional/semantic tests;
- consumer probes from geodesy/geometry use cases.

Current M2 scope evidence selects metre, kilometre, international foot, and US
survey foot. The geospatial consumer audit found no concrete centimetre or
millimetre requirement, so those units remain deferred rather than being added
speculatively. The public-unit consumer and compile-negative gates pass on the
DMD 2.111 / LDC 1.41 baseline; final release-build and branch-review gates
remain before M2 is closed.

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


## Consumer integration policy

A domain library with a documented canonical-unit scalar API does not
automatically require quantities-d.

Prefer:

- dependency-light scalar kernels with explicit documented unit contracts where
  the domain already has a clear canonical convention;
- strong domain types where the domain itself owns the distinction;
- optional quantities-d boundary adapters when users benefit from compile-time
  dimension/unit checking and conversion;
- a hard quantities-d dependency only when concrete consumer evidence shows
  quantities are part of the library's core semantic model.

The current geospatial consumer audit does not justify a hard dependency from
geodesy-d, geo-d, geo3-d, raster-d, or imagery-d.
