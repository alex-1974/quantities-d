# R15 Probe 15: direct floating targets through the Unit API

Research only. The shadow `quantities.conversion` starts from develop
`73e8401c5ac7b1cedbaacf33dab1814acda98bbb` (merged carrier fix #49).
It appends the candidate mixed-Rep API without modifying production sources.

## Scope and contract under test

`checkedQuantityAs!(Spec, Unit, TargetRep)` / `exactQuantityAs` and
`checkedInAs!(Unit, TargetRep)` / `exactInAs` deduce the represented source.
For floating targets, supported sources are `long`, `ulong`, `float`, `double`
and trait-qualified `real`; targets are `float` and `double`. Probe 14's
floating-to-`long` checked/exact/explicit-rounding paths remain available.
Integer rounding modes are rejected for floating targets. Names remain candidates.

The exact represented source and both rational Unit scales reach one direct
nearest-even target rounding. Exact mathematical range is checked before rounding.
Checked inexact finite results carry the rounded value; exact-required inexact
results carry only failure. Non-finite sources and overflow carry no value.
Signed zero includes the sign of the composed ratio. Carrier checks execute in
debug and release, with D `out` initialization accounted for explicitly.

Eight Spec/Unit pairs exercise metre, international foot, survey foot, large
coprime scales, non-metre canonical scales, a negative canonical scale, and two
boundary fixtures. The direct-rounding witness uses
`1 + 2^-24 + 2^-60`: direct float rounding produces `0x3f800001`, while rounding
through double then casting to float produces `0x3f800000`. A separate near-max
fixture checks mathematical overflow even when target rounding could hide it.

## Verification

The Python oracle uses independent `Fraction` arithmetic and target bit patterns
for construction and extraction. Fixed edge cases and deterministic random cases
cover integer extremes, normal/subnormal boundaries, zeros, non-finite sources,
and both targets. The workflow runs DMD and LDC in debug and release, then reruns
Probe 14's oracle against this extended shadow API. The consumer also checks
const/immutable deduction, `@safe pure nothrow @nogc`, rejected types/modes and
rejected ordinary CTFE use of this runtime floating path.

## Results

Tested code: `d526ce38a858605b5899878f784377e31827844f`.
[CI run 36825924441](https://github.com/alex-1974/quantities-d/actions/runs/36825924441)
passed on DMD 2.111.0 and LDC 1.41.0, each in debug and release.
Every build compared 22,176 API pairs / 44,352 directions with zero mismatches:
1,080 checked exact, 18,614 checked inexact, 1,117 exact-required values,
21,293 exact-required failures, 1,876 checked overflow and 372 checked nonFinite.
The consumer's direct-rounding negative control and compile-negative gates passed.
Probe 14 also passed against this extended API in every build: 13,620 pairs /
27,240 directions. Probes 10–14's existing workflow steps remained green.
The evidenced real format is binary80 `(64, -16381, 16384)`.

This probe does not qualify performance, compiler
cost, general CTFE support, alternative real formats, final API naming, or
production promotion. The supported real trait alternatives are binary80 and
binary64-like; only the actual CI format is evidenced by its reported traits.

Next: reconcile candidate names with earlier R15 API research and explicitly
decide the mixed-Rep range/rounding contract. Then qualify implementation cost
before selective production promotion; this research branch is not a merge unit.
