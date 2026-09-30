# R15 — Explicit TargetRep follow-up

**Issue:** #42  
**Status:** Active research  
**Base:** develop@73a0897c08bf4d888c894393fcbe94ab4717c077

## Baseline correction

R15 Probe 1/2 found that the former overload surface admitted unsupported
source Reps through implicit D argument conversion before quantities-d could
classify the represented source value.

Issue #44 / PR #45 repaired that production defect. Construction conversion now
accepts only the explicitly promoted source Reps.

R15 continues from this corrected baseline.

## Probe 3 — explicit target, deduced source

A future mixed-Rep conversion entry point must satisfy two structural rules:

1. `SourceRep` is deduced from the actual caller expression and never supplied
   through an implicitly converting function parameter;
2. `TargetRep` is explicit in the request.

The research syntax is intentionally provisional:

```d
value.checkedQuantityR15!(Spec, Unit, TargetRep)
quantity.checkedInR15!(Unit, TargetRep)
```

The key result is not the spelling. The key result is that `ulong`, `real`,
and qualified `const`/immutable forms preserve their actual source
representation at the API boundary.

## Probe 4 — representation-pair classes

Before Unit rescale is considered, SourceRep -> TargetRep pairs fall into
different semantic classes.

### totalExact

Every represented source value is exactly representable in the target Rep.

Examples depend on target properties:

- float -> double;
- double -> sufficiently wide real;
- sufficiently narrow integral domain -> floating target.

A total-exact representation pair does not by itself make a Unit conversion
total: a nontrivial exact rational Unit scale may still make the final target
value inexact or overflow.

### valueDependentExact

The representation pair is not a total inclusion, but individual values may be
exact.

Examples:

- long -> double;
- double -> float;
- real80-like real -> double;
- many integral narrowing conversions.

These require checked/exact-required semantics for loss-sensitive conversion.

### checkedRounded

Floating -> integral needs both range and fractional-value handling.

It must distinguish:

- exact integral finite value;
- finite fractional value;
- overflow;
- NaN / infinity.

Explicit rounding policy is a separate caller intent from checked/exact.

## Important separation

R15 must keep two independent layers:

```text
represented SourceRep
    -> exact Unit rational rescale
    -> target mathematical value
    -> TargetRep classification / rounding
```

Pair inclusion is useful for fast paths and totality proofs, but it cannot
replace exact rational Unit-rescale analysis.

## Next probe

Probe 5 will implement identity-scale mixed-Rep classification for representative
pairs and compare status/results against an independent exact-value model before
introducing nontrivial Unit scales.
