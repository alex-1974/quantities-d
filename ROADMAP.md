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

M2 is complete. PR #11 merged the minimal public length catalogue after the
DMD 2.111 / LDC 1.41 debug, release, compile-negative, external-consumer, and
branch-review gates passed.

The accepted M2 scope is metre, kilometre, international foot, and US survey
foot. The geospatial consumer audit found no concrete centimetre or millimetre
requirement, so those units remain deferred rather than being added
speculatively.

## M3 — Quantity semantics and derived operations

M3 starts with research rather than production API expansion. R04 owns
arithmetic semantics; the still-open concrete Spec questions from R05 own
semantic distinctions such as distance/radius/height.

Evaluate from real consumers:

- whether generic `Length` remains sufficient at reusable library boundaries
  or concrete distance/radius/height Specs provide justified type safety;
- which same-Spec and cross-Spec addition/subtraction operations are meaningful;
- multiplication/division and the minimum justified derived-dimension model;
- area as the first candidate derived dimension;
- dimensionless results and scalar multiplication/division;
- mixed-unit arithmetic ergonomics without bypassing the accepted conversion
  intent/loss contract;
- `Rep` result and promotion rules;
- mathematical functions such as `abs`, `sqrt`, and `hypot` only where
  numerical consumers demonstrate a need;
- CTFE, UFCS, `@safe`, `pure`, `nothrow`, and `@nogc` viability;
- code-generation and compile-time cost before any zero-overhead claim.

R04 has now produced enough evidence-backed decisions for the first production
slice. PR #15 promotes:

- operation-safe integral result-Rep selection for addition, subtraction,
  multiplication, and exact division;
- explicit Spec capabilities separating semantic validity from representation
  safety;
- same-Spec integral `Length + Length` and `Length - Length`;
- symmetric integral scalar multiplication for scalable Specs;
- explicit integral `exactDiv` with exact, inexact, and division-by-zero
  outcomes;
- constructive `DivisionResult` states and positive/negative external API
  gates.

This is a partial M3 implementation, not M3 completion. Floating-point
arithmetic, cross-Spec relationships, `Quantity * Quantity`, derived
dimensions such as Area, dimensionless Quantity results, Class-O named checked
arithmetic, broader promotion policy, and consumer-driven mathematical
functions remain open research-first work.

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
